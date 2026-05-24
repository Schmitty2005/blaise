{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Andrew Haines
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{ uUnitInterfaceIO — text-based serializer / deserializer for
  TUnitInterface.

  Phase 6c-E starter.  The on-disk story for separate compilation
  needs a stable, parser-free way to materialise a TUnitInterface
  from a byte sequence.  This unit owns that mapping.

  Format (v1):
    Magic + version on a single line, then length-prefixed string
    records.  Lengths are decimal ASCII followed by ':' and the
    raw bytes (no escaping needed since lengths drive consumption).

    BLAISE-IFACE 1\n
    <unit-name lpstr>
    CONST <count>\n
      <name lpstr><typeref lpstr><int64><strval lpstr><flags byte>
    END\n

  Where:
    <lpstr>     = "<decimal-len>:" followed by <len> raw bytes
    <int64>     = lpstr containing the decimal digits
    <flags byte>= '0' / '1' / '2' / '3'
                  bit 0 = IsString, bit 1 = IsFloat

  TypeRef is rendered as "UnitName.TypeName" — '$builtin.Integer',
  '<thisunit>.TFoo', or '.<empty>' for untyped consts.

  Scope of this commit: unit name + const records only.  Vars,
  types, routines, and class/generic bodies land in follow-up
  commits.  The plumbing — magic header, length-prefixed strings,
  cursor-based reader — is the load-bearing part; extending it to
  more record types is mechanical.

  Why text and not binary: easier to diff and inspect during
  development, no endianness concerns, no bit-twiddling.  Once the
  layout stabilises we can re-encode as a compact binary form
  without changing the surface API. }

unit uUnitInterfaceIO;

interface

uses
  Classes, SysUtils, streams, uAST, uUnitInterface;

const
  IFACE_MAGIC   = 'BLAISE-IFACE';
  IFACE_VERSION = 1;

type
  EIfaceFormatError = class(Exception);

{ Render AIface into a string.  Caller owns the buffer. }
function WriteUnitInterface(AIface: TUnitInterface): string;

{ Parse AText into a freshly-allocated TUnitInterface.  Caller owns
  the returned interface.  Raises EIfaceFormatError on a malformed
  input or version mismatch. }
function ReadUnitInterface(const AText: string): TUnitInterface;

{ File wrappers.  Caller owns the returned interface. }
procedure WriteUnitInterfaceToFile(AIface: TUnitInterface; const APath: string);
function  ReadUnitInterfaceFromFile(const APath: string): TUnitInterface;

implementation

{ ----- Writer ----------------------------------------------------- }

{ Length-prefixed string: "<len>:bytes".  Lets the reader consume
  exactly <len> UTF-8 bytes without worrying about embedded ':',
  newlines, or quotes. }
function EncodeLpstr(const S: string): string;
begin
  Result := IntToStr(Length(S)) + ':' + S;
end;

function EncodeInt64(V: Int64): string;
begin
  Result := EncodeLpstr(IntToStr(V));
end;

function EncodeFlags(AIsString, AIsFloat: Boolean): string;
var
  B: Integer;
begin
  B := 0;
  if AIsString then B := B or 1;
  if AIsFloat  then B := B or 2;
  Result := IntToStr(B);
end;

{ Pass the ref as two strings to dodge the documented record-with-
  strings-as-const-param codegen bug (memory:
  project_record_const_param_crash.md). }
function EncodeQualRefParts(const AUnitName, ATypeName: string): string;
begin
  Result := EncodeLpstr(AUnitName + '.' + ATypeName);
end;

function WriteConsts(AIface: TUnitInterface): string;
var
  I:  Integer;
  C:  TConstEntry;
  SB: TStringList;
begin
  SB := TStringList.Create;
  try
    SB.Add('CONST ' + IntToStr(AIface.Consts.Count));
    for I := 0 to AIface.Consts.Count - 1 do
    begin
      C := TConstEntry(AIface.Consts.Items[I]);
      SB.Add(
        EncodeLpstr(C.Decl.Name) +
        EncodeQualRefParts(C.TypeRef.UnitName, C.TypeRef.TypeName) +
        EncodeInt64(C.Decl.IntVal) +
        EncodeLpstr(C.Decl.StrVal) +
        EncodeFlags(C.Decl.IsString, C.Decl.IsFloat));
    end;
    SB.Add('END');
    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

function WriteVars(AIface: TUnitInterface): string;
var
  I:  Integer;
  V:  TVarEntry;
  SB: TStringList;
begin
  SB := TStringList.Create;
  try
    SB.Add('VAR ' + IntToStr(AIface.Vars.Count));
    for I := 0 to AIface.Vars.Count - 1 do
    begin
      V := TVarEntry(AIface.Vars.Items[I]);
      SB.Add(
        EncodeLpstr(V.Name) +
        EncodeQualRefParts(V.TypeRef.UnitName, V.TypeRef.TypeName));
    end;
    SB.Add('END');
    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

{ Encode an enum's member list as comma-joined names within an lpstr.
  Commas are safe inside lpstr since the outer length drives parsing. }
function EncodeEnumMembers(AEnum: TEnumTypeDef): string;
var
  I:    Integer;
  Acc:  string;
begin
  Acc := '';
  for I := 0 to AEnum.Members.Count - 1 do
  begin
    if I > 0 then Acc := Acc + ',';
    Acc := Acc + AEnum.Members.Strings[I];
  end;
  Result := EncodeLpstr(Acc);
end;

{ Tag a TTypeEntry by what its Def is.  Procedural, generic, and
  generic-interface kinds are still skipped on write — they need
  richer payloads (param resolution / template parameter lists) and
  belong in follow-up commits along with inline + generic bodies. }
function TypeEntryKind(AEntry: TTypeEntry): string;
begin
  if      AEntry.Def is TEnumTypeDef       then Result := 'enum'
  else if AEntry.Def is TSetTypeDef        then Result := 'set'
  else if AEntry.Def is TTypeAliasDef      then Result := 'alias'
  else if AEntry.Def is TRecordTypeDef     then Result := 'record'
  else if AEntry.Def is TClassTypeDef      then Result := 'class'
  else if AEntry.Def is TInterfaceTypeDef  then Result := 'interface'
  else if AEntry.Def is TProceduralTypeDef then Result := 'proc'
  else                                          Result := '';
end;

{ ----- TYPE-block payload helpers --------------------------------

  Every value emitted into the TYPE block is an lpstr.  Numeric
  counts and boolean flags are stringified into lpstrs too, which
  costs a few extra bytes but keeps the reader's primitive set
  trivially small (only ReadLpstrAt).  Sequences (attributes,
  implements, fields, methods) are emitted as a count lpstr
  followed by `count` records. }

function EncodeCount(N: Integer): string;
begin
  Result := EncodeLpstr(IntToStr(N));
end;

function EncodeBool(B: Boolean): string;
begin
  if B then Result := EncodeLpstr('1')
       else Result := EncodeLpstr('0');
end;

function EncodeStringList(ASL: TStringList): string;
var
  I: Integer;
begin
  Result := EncodeCount(ASL.Count);
  for I := 0 to ASL.Count - 1 do
    Result := Result + EncodeLpstr(ASL.Strings[I]);
end;

function EncodeFieldList(AFields: TObjectList): string;
var
  I, J: Integer;
  F:    TFieldDecl;
  TotalNames: Integer;
begin
  { TFieldDecl carries Names: TStringList (multi-name fields like
    'X, Y: Integer').  Flatten to one record per name for symmetry
    with how TSymbolTable.AddField is called. }
  TotalNames := 0;
  for I := 0 to AFields.Count - 1 do
    Inc(TotalNames, TFieldDecl(AFields.Items[I]).Names.Count);

  Result := EncodeCount(TotalNames);
  for I := 0 to AFields.Count - 1 do
  begin
    F := TFieldDecl(AFields.Items[I]);
    for J := 0 to F.Names.Count - 1 do
      Result := Result +
                EncodeLpstr(F.Names.Strings[J]) +
                EncodeLpstr(F.TypeName) +
                EncodeBool(F.IsWeak);
  end;
end;

{ Per-method routine sig including class-method extras
  (VTableSlot, ResolvedQbeName, IsVirtual, IsOverride).  Used by
  class + interface payloads. }
function EncodeMethodSig(AR: TRoutineSig): string;
var
  J: Integer;
  P: TMethodParam;
begin
  Result :=
    EncodeLpstr(AR.Name) +
    EncodeBool (AR.IsFunction) +
    EncodeQualRefParts(AR.ReturnType.UnitName, AR.ReturnType.TypeName) +
    EncodeBool (AR.IsVirtual) +
    EncodeBool (AR.IsOverride) +
    EncodeLpstr(AR.ResolvedQbeName) +
    EncodeLpstr(IntToStr(AR.VTableSlot)) +
    EncodeCount(AR.Params.Count);
  for J := 0 to AR.Params.Count - 1 do
  begin
    P := TMethodParam(AR.Params.Items[J]);
    Result := Result +
              EncodeLpstr(P.ParamName) +
              EncodeLpstr(P.TypeName) +
              EncodeParamFlags(P);
  end;
end;

function EncodeMethodList(AMethods: TObjectList): string;
var
  I: Integer;
begin
  Result := EncodeCount(AMethods.Count);
  for I := 0 to AMethods.Count - 1 do
    Result := Result + EncodeMethodSig(TRoutineSig(AMethods.Items[I]));
end;

function WriteRecordPayload(AEntry: TTypeEntry): string;
var
  Def: TRecordTypeDef;
begin
  Def := TRecordTypeDef(AEntry.Def);
  Result := EncodeBool(Def.IsPacked) +
            EncodeFieldList(Def.Fields);
end;

function WriteClassPayload(AEntry: TTypeEntry): string;
var
  Def: TClassTypeDef;
begin
  Def := TClassTypeDef(AEntry.Def);
  Result :=
    EncodeQualRefParts(AEntry.ParentClass.UnitName, AEntry.ParentClass.TypeName) +
    EncodeLpstr(IntToStr(AEntry.InstanceSize)) +
    EncodeStringList(AEntry.Attributes) +
    EncodeStringList(AEntry.Implements) +
    EncodeFieldList(Def.Fields) +
    EncodeMethodList(AEntry.Methods);
end;

{ Encode a TMethodDecl (AST) using the same per-method payload shape
  as EncodeMethodSig, but pulling fields off the AST node.  Interface
  methods live in Def.Methods (TInterfaceTypeDef carries them
  natively), not in AEntry.Methods.  This keeps the writer and the
  importer (uSemanticImport.RegisterInterface, which walks
  Def.Methods) symmetric. }
function EncodeMethodDecl(AM: TMethodDecl): string;
var
  J: Integer;
  P: TMethodParam;
begin
  Result :=
    EncodeLpstr(AM.Name) +
    EncodeBool (AM.ReturnTypeName <> '') +
    EncodeLpstr(AM.ReturnTypeName) +  { stored raw, not a qualref —
                                         interfaces don't carry
                                         resolved cross-unit refs }
    EncodeBool (AM.IsVirtual) +
    EncodeBool (AM.IsOverride) +
    EncodeCount(AM.Params.Count);
  for J := 0 to AM.Params.Count - 1 do
  begin
    P := TMethodParam(AM.Params.Items[J]);
    Result := Result +
              EncodeLpstr(P.ParamName) +
              EncodeLpstr(P.TypeName) +
              EncodeParamFlags(P);
  end;
end;

function EncodeMethodDeclList(AList: TObjectList): string;
var
  I: Integer;
begin
  Result := EncodeCount(AList.Count);
  for I := 0 to AList.Count - 1 do
    Result := Result + EncodeMethodDecl(TMethodDecl(AList.Items[I]));
end;

function WriteProcPayload(AEntry: TTypeEntry): string;
var
  Def: TProceduralTypeDef;
  J:   Integer;
  P:   TMethodParam;
begin
  Def := TProceduralTypeDef(AEntry.Def);
  Result :=
    EncodeBool (Def.IsFunction) +
    EncodeBool (Def.IsMethodPtr) +
    EncodeLpstr(Def.ReturnTypeName) +
    EncodeCount(Def.Params.Count);
  for J := 0 to Def.Params.Count - 1 do
  begin
    P := TMethodParam(Def.Params.Items[J]);
    Result := Result +
              EncodeLpstr(P.ParamName) +
              EncodeLpstr(P.TypeName) +
              EncodeParamFlags(P);
  end;
end;

function WriteInterfacePayload(AEntry: TTypeEntry): string;
var
  Def: TInterfaceTypeDef;
begin
  Def := TInterfaceTypeDef(AEntry.Def);
  Result :=
    EncodeLpstr(Def.ParentName) +
    EncodeMethodDeclList(Def.Methods);
end;

function WriteTypes(AIface: TUnitInterface): string;
var
  I:      Integer;
  E:      TTypeEntry;
  SB:     TStringList;
  Kind:   string;
  Eligible: TObjectList;
begin
  Eligible := TObjectList.Create(False);
  SB := TStringList.Create;
  try
    for I := 0 to AIface.Types.Count - 1 do
    begin
      E := TTypeEntry(AIface.Types.Items[I]);
      if TypeEntryKind(E) <> '' then Eligible.Add(E);
    end;

    SB.Add('TYPE ' + IntToStr(Eligible.Count));
    for I := 0 to Eligible.Count - 1 do
    begin
      E := TTypeEntry(Eligible.Items[I]);
      Kind := TypeEntryKind(E);
      if Kind = 'enum' then
        SB.Add(EncodeLpstr('enum') +
               EncodeLpstr(E.Name) +
               EncodeEnumMembers(TEnumTypeDef(E.Def)))
      else if Kind = 'set' then
        SB.Add(EncodeLpstr('set') +
               EncodeLpstr(E.Name) +
               EncodeLpstr(TSetTypeDef(E.Def).BaseTypeName))
      else if Kind = 'alias' then
        SB.Add(EncodeLpstr('alias') +
               EncodeLpstr(E.Name) +
               EncodeLpstr(TTypeAliasDef(E.Def).TypeName))
      else if Kind = 'record' then
        SB.Add(EncodeLpstr('record') +
               EncodeLpstr(E.Name) +
               WriteRecordPayload(E))
      else if Kind = 'class' then
        SB.Add(EncodeLpstr('class') +
               EncodeLpstr(E.Name) +
               WriteClassPayload(E))
      else if Kind = 'interface' then
        SB.Add(EncodeLpstr('interface') +
               EncodeLpstr(E.Name) +
               WriteInterfacePayload(E))
      else { proc }
        SB.Add(EncodeLpstr('proc') +
               EncodeLpstr(E.Name) +
               WriteProcPayload(E));
    end;
    SB.Add('END');
    Result := SB.Text;
  finally
    SB.Free;
    Eligible.Free;
  end;
end;

{ Param flags pack: bit 0 = IsVar, bit 1 = IsConst, bit 2 = IsOpenArray.
  Render as a single decimal-digit lpstr for symmetry with the rest
  of the format. }
function EncodeParamFlags(AParam: TMethodParam): string;
var
  B: Integer;
begin
  B := 0;
  if AParam.IsVarParam   then B := B or 1;
  if AParam.IsConstParam then B := B or 2;
  if AParam.IsOpenArray  then B := B or 4;
  Result := EncodeLpstr(IntToStr(B));
end;

function WriteRoutines(AIface: TUnitInterface): string;
var
  I, J:   Integer;
  R:      TRoutineSig;
  P:      TMethodParam;
  SB:     TStringList;
  Line:   string;
begin
  SB := TStringList.Create;
  try
    SB.Add('ROUT ' + IntToStr(AIface.Routines.Count));
    for I := 0 to AIface.Routines.Count - 1 do
    begin
      R := TRoutineSig(AIface.Routines.Items[I]);
      Line :=
        EncodeLpstr(R.Name) +
        EncodeLpstr(IntToStr(Ord(R.IsFunction))) +
        EncodeQualRefParts(R.ReturnType.UnitName, R.ReturnType.TypeName) +
        EncodeLpstr(R.ResolvedQbeName) +
        EncodeLpstr(IntToStr(R.Params.Count));
      for J := 0 to R.Params.Count - 1 do
      begin
        P    := TMethodParam(R.Params.Items[J]);
        Line := Line +
                EncodeLpstr(P.ParamName) +
                EncodeLpstr(P.TypeName) +
                EncodeParamFlags(P);
      end;
      SB.Add(Line);
    end;
    SB.Add('END');
    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

function WriteMeta(AIface: TUnitInterface): string;
var
  SB: TStringList;
begin
  SB := TStringList.Create;
  try
    SB.Add('META');
    SB.Add(EncodeLpstr(AIface.SourceFile) +
           EncodeLpstr(AIface.SourceHash) +
           EncodeLpstr(AIface.CompilerVersion) +
           EncodeStringList(AIface.UsedUnits));
    SB.Add('END');
    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

function WriteUnitInterface(AIface: TUnitInterface): string;
begin
  Result :=
    IFACE_MAGIC + ' ' + IntToStr(IFACE_VERSION) + #10 +
    EncodeLpstr(AIface.Name) + #10 +
    WriteMeta    (AIface) +
    WriteTypes   (AIface) +
    WriteConsts  (AIface) +
    WriteVars    (AIface) +
    WriteRoutines(AIface);
end;

{ ----- Reader ----------------------------------------------------- }

{ Cursor state passed by var-ref into the per-record readers — keeps
  the API surface scalar-friendly so we avoid the const-record-param
  string-field crash documented in memory. }

{ Char-classification on integer ordinals — Blaise lacks a Char
  type and S[i] returns a 1-byte string, so route through Ord() to
  get scalar Integer comparisons. }
function IsWhitespaceOrd(C: Integer): Boolean;
begin
  Result := (C = 32) or (C = 9) or (C = 10) or (C = 13);
end;

function IsUpperOrd(C: Integer): Boolean;
begin
  Result := (C >= Ord('A')) and (C <= Ord('Z'));
end;

function IsDigitOrd(C: Integer): Boolean;
begin
  Result := (C >= Ord('0')) and (C <= Ord('9'));
end;

{ Indexing convention throughout this unit: Blaise strings are
  0-indexed.  S[0] is the first byte; valid positions are 0 ..
  Length(S)-1.  Copy(S, start, len) treats start as 0-based.  Pos
  returns 0-based offset or -1 for not found.  APos cursor is
  0-based. }

procedure SkipWhitespace(const AText: string; var APos: Integer);
begin
  while (APos < Length(AText)) and IsWhitespaceOrd(Ord(AText[APos])) do
    Inc(APos);
end;

function ReadLpstrAt(const AText: string; var APos: Integer): string;
var
  ColonPos: Integer;
  Len:      Integer;
  LenStr:   string;
begin
  SkipWhitespace(AText, APos);
  ColonPos := APos;
  while (ColonPos < Length(AText)) and (AText[ColonPos] <> ':') do
    Inc(ColonPos);
  if ColonPos >= Length(AText) then
    raise EIfaceFormatError.Create('lpstr: missing '':'' separator');
  LenStr := Copy(AText, APos, ColonPos - APos);
  Len    := StrToInt(LenStr);
  if ColonPos + 1 + Len > Length(AText) then
    raise EIfaceFormatError.Create(Format(
      'lpstr: %d bytes requested, only %d available', [Len, Length(AText) - ColonPos - 1]));
  Result := Copy(AText, ColonPos + 1, Len);
  APos   := ColonPos + 1 + Len;
end;

function ReadInt64At(const AText: string; var APos: Integer): Int64;
begin
  Result := StrToInt64(ReadLpstrAt(AText, APos));
end;

function ReadFlagsAt(const AText: string; var APos: Integer;
                     out AIsString, AIsFloat: Boolean): Integer;
var
  B: Integer;
begin
  SkipWhitespace(AText, APos);
  if APos >= Length(AText) then
    raise EIfaceFormatError.Create('flags: end-of-input');
  B := Ord(AText[APos]) - Ord('0');
  Inc(APos);
  AIsString := (B and 1) <> 0;
  AIsFloat  := (B and 2) <> 0;
  Result := B;
end;

{ Split 'Unit.Type' into two strings.  Avoids passing TQualTypeRef
  records — same record-with-strings codegen bug that bit
  uSemanticImport.ResolveRef. }
procedure DecodeQualRef(const ASrc: string; var AUnit, AType: string);
var
  Dot: Integer;
begin
  { Blaise Pos and Copy are 0-based. }
  Dot := Pos('.', ASrc);
  if Dot < 0 then
  begin
    AUnit := '';
    AType := ASrc;
  end
  else
  begin
    AUnit := Copy(ASrc, 0, Dot);
    AType := Copy(ASrc, Dot + 1, Length(ASrc) - Dot - 1);
  end;
end;

{ Read an unterminated keyword (letters only) at the current cursor;
  consume it and advance past trailing whitespace.  Used for record
  tags ('CONST', 'END', etc.). }
function ReadTag(const AText: string; var APos: Integer): string;
var
  Start: Integer;
begin
  SkipWhitespace(AText, APos);
  Start := APos;
  while (APos < Length(AText)) and IsUpperOrd(Ord(AText[APos])) do
    Inc(APos);
  Result := Copy(AText, Start, APos - Start);
end;

function ReadDecimalAt(const AText: string; var APos: Integer): Integer;
var
  Start: Integer;
begin
  SkipWhitespace(AText, APos);
  Start := APos;
  while (APos < Length(AText)) and IsDigitOrd(Ord(AText[APos])) do
    Inc(APos);
  if APos = Start then
    raise EIfaceFormatError.Create('expected decimal digits');
  Result := StrToInt(Copy(AText, Start, APos - Start));
end;

procedure ReadHeader(const AText: string; var APos: Integer);
var
  MagicPos: Integer;
  Ver:      Integer;
begin
  SkipWhitespace(AText, APos);
  { Blaise Pos: 0-based result, -1 = not found.  Match at the
    cursor's current position means MagicPos = APos. }
  MagicPos := Pos(IFACE_MAGIC, AText);
  if MagicPos < 0 then
    raise EIfaceFormatError.Create('missing magic header');
  if MagicPos <> APos then
    raise EIfaceFormatError.Create(Format(
      'magic ''%s'' not at expected position %d (found at %d)',
      [IFACE_MAGIC, APos, MagicPos]));
  Inc(APos, Length(IFACE_MAGIC));
  SkipWhitespace(AText, APos);
  Ver := ReadDecimalAt(AText, APos);
  if Ver <> IFACE_VERSION then
    raise EIfaceFormatError.Create(Format(
      'unsupported version %d (this build understands %d)',
      [Ver, IFACE_VERSION]));
end;

procedure ReadConsts(const AText: string; var APos: Integer;
                     AIface: TUnitInterface);
var
  Count:    Integer;
  I:        Integer;
  Entry:    TConstEntry;
  Name:     string;
  RefStr:   string;
  IntVal:   Int64;
  StrVal:   string;
  IsString: Boolean;
  IsFloat:  Boolean;
  RefUnit:  string;
  RefType:  string;
begin
  Count := ReadDecimalAt(AText, APos);
  for I := 1 to Count do
  begin
    Name     := ReadLpstrAt(AText, APos);
    RefStr   := ReadLpstrAt(AText, APos);
    IntVal   := ReadInt64At(AText, APos);
    StrVal   := ReadLpstrAt(AText, APos);
    ReadFlagsAt(AText, APos, IsString, IsFloat);
    DecodeQualRef(RefStr, RefUnit, RefType);

    Entry := TConstEntry.Create;
    Entry.Decl := TConstDecl.Create;
    Entry.Decl.Name     := Name;
    Entry.Decl.IntVal   := IntVal;
    Entry.Decl.StrVal   := StrVal;
    Entry.Decl.IsString := IsString;
    Entry.Decl.IsFloat  := IsFloat;
    Entry.TypeRef       := MakeQualRef(RefUnit, RefType);
    AIface.AddConst(Entry);
  end;
  { Trailing 'END' marker — keeps the format extensible: future
    record types follow the same tag/payload/END pattern. }
  if ReadTag(AText, APos) <> 'END' then
    raise EIfaceFormatError.Create('CONST block: missing END marker');
end;

procedure ReadVars(const AText: string; var APos: Integer;
                   AIface: TUnitInterface);
var
  Count:   Integer;
  I:       Integer;
  Entry:   TVarEntry;
  RefStr:  string;
  RefUnit: string;
  RefType: string;
begin
  Count := ReadDecimalAt(AText, APos);
  for I := 1 to Count do
  begin
    Entry := TVarEntry.Create;
    Entry.Name := ReadLpstrAt(AText, APos);
    RefStr     := ReadLpstrAt(AText, APos);
    DecodeQualRef(RefStr, RefUnit, RefType);
    Entry.TypeRef := MakeQualRef(RefUnit, RefType);
    AIface.AddVar(Entry);
  end;
  if ReadTag(AText, APos) <> 'END' then
    raise EIfaceFormatError.Create('VAR block: missing END marker');
end;

{ Split a comma-joined member list back into a TStringList.  Empty
  input ⇒ empty list. }
procedure SplitMembers(const ASrc: string; ATarget: TStringList);
var
  Cur: string;
  P:   Integer;
begin
  Cur := ASrc;
  P   := Pos(',', Cur);
  while P >= 0 do
  begin
    ATarget.Add(Copy(Cur, 0, P));
    Cur := Copy(Cur, P + 1, Length(Cur) - P - 1);
    P   := Pos(',', Cur);
  end;
  if Length(Cur) > 0 then ATarget.Add(Cur);
end;

function DecodeCount(const AText: string; var APos: Integer): Integer;
begin
  Result := StrToInt(ReadLpstrAt(AText, APos));
end;

function DecodeBool(const AText: string; var APos: Integer): Boolean;
begin
  Result := ReadLpstrAt(AText, APos) = '1';
end;

procedure ReadStringListBlock(const AText: string; var APos: Integer;
                              ATarget: TStringList);
var
  C, I: Integer;
begin
  C := DecodeCount(AText, APos);
  for I := 1 to C do ATarget.Add(ReadLpstrAt(AText, APos));
end;

{ Read a flattened field list into a TRecordTypeDef's Fields list.
  Each field is emitted with a single Name (the writer flattened
  multi-name decls); the reader rebuilds one TFieldDecl per name. }
procedure ReadFieldList(const AText: string; var APos: Integer;
                        ATarget: TObjectList);
var
  C, I:    Integer;
  FldName: string;
  FldType: string;
  IsWeak:  Boolean;
  F:       TFieldDecl;
begin
  C := DecodeCount(AText, APos);
  for I := 1 to C do
  begin
    FldName := ReadLpstrAt(AText, APos);
    FldType := ReadLpstrAt(AText, APos);
    IsWeak  := DecodeBool(AText, APos);
    F := TFieldDecl.Create;
    F.Names.Add(FldName);
    F.TypeName := FldType;
    F.IsWeak   := IsWeak;
    ATarget.Add(F);
  end;
end;

{ Inverse of EncodeMethodSig — builds a TRoutineSig from the
  per-method payload. }
function ReadMethodSig(const AText: string; var APos: Integer): TRoutineSig;
var
  RefStr:   string;
  RefUnit:  string;
  RefType:  string;
  Pc, J:    Integer;
  Param:    TMethodParam;
  FlagsStr: string;
begin
  Result := TRoutineSig.Create;
  Result.Name        := ReadLpstrAt(AText, APos);
  Result.IsFunction  := DecodeBool(AText, APos);
  RefStr             := ReadLpstrAt(AText, APos);
  DecodeQualRef(RefStr, RefUnit, RefType);
  Result.ReturnType  := MakeQualRef(RefUnit, RefType);
  Result.IsVirtual   := DecodeBool(AText, APos);
  Result.IsOverride  := DecodeBool(AText, APos);
  Result.ResolvedQbeName := ReadLpstrAt(AText, APos);
  Result.VTableSlot  := StrToInt(ReadLpstrAt(AText, APos));
  Pc := DecodeCount(AText, APos);
  for J := 1 to Pc do
  begin
    Param := TMethodParam.Create;
    Param.ParamName := ReadLpstrAt(AText, APos);
    Param.TypeName  := ReadLpstrAt(AText, APos);
    FlagsStr := ReadLpstrAt(AText, APos);
    DecodeParamFlags(StrToInt(FlagsStr), Param);
    Result.Params.Add(Param);
  end;
end;

procedure ReadMethodList(const AText: string; var APos: Integer;
                         ATarget: TObjectList);
var
  C, I: Integer;
begin
  C := DecodeCount(AText, APos);
  for I := 1 to C do ATarget.Add(ReadMethodSig(AText, APos));
end;

procedure ReadRecordPayload(const AText: string; var APos: Integer;
                            AEntry: TTypeEntry);
var
  Def: TRecordTypeDef;
begin
  Def := TRecordTypeDef.Create;
  Def.IsPacked := DecodeBool(AText, APos);
  ReadFieldList(AText, APos, Def.Fields);
  AEntry.Def := Def;
end;

procedure ReadClassPayload(const AText: string; var APos: Integer;
                           AEntry: TTypeEntry);
var
  Def:     TClassTypeDef;
  RefStr:  string;
  RefUnit: string;
  RefType: string;
begin
  Def := TClassTypeDef.Create;
  RefStr := ReadLpstrAt(AText, APos);
  DecodeQualRef(RefStr, RefUnit, RefType);
  AEntry.ParentClass  := MakeQualRef(RefUnit, RefType);
  Def.ParentName      := RefType;
  AEntry.InstanceSize := StrToInt64(ReadLpstrAt(AText, APos));
  ReadStringListBlock(AText, APos, AEntry.Attributes);
  ReadStringListBlock(AText, APos, AEntry.Implements);
  ReadFieldList(AText, APos, Def.Fields);
  ReadMethodList(AText, APos, AEntry.Methods);
  AEntry.IsClass := True;
  AEntry.Def     := Def;
end;

function ReadMethodDecl(const AText: string; var APos: Integer): TMethodDecl;
var
  HasReturn: Boolean;
  Pc, J:     Integer;
  Param:     TMethodParam;
  FlagsStr:  string;
begin
  Result := TMethodDecl.Create;
  Result.Name           := ReadLpstrAt(AText, APos);
  HasReturn             := DecodeBool(AText, APos);
  Result.ReturnTypeName := ReadLpstrAt(AText, APos);
  if not HasReturn then Result.ReturnTypeName := '';
  Result.IsVirtual      := DecodeBool(AText, APos);
  Result.IsOverride     := DecodeBool(AText, APos);
  Pc := DecodeCount(AText, APos);
  for J := 1 to Pc do
  begin
    Param := TMethodParam.Create;
    Param.ParamName := ReadLpstrAt(AText, APos);
    Param.TypeName  := ReadLpstrAt(AText, APos);
    FlagsStr := ReadLpstrAt(AText, APos);
    DecodeParamFlags(StrToInt(FlagsStr), Param);
    Result.Params.Add(Param);
  end;
end;

procedure ReadMethodDeclList(const AText: string; var APos: Integer;
                             ATarget: TObjectList);
var
  C, I: Integer;
begin
  C := DecodeCount(AText, APos);
  for I := 1 to C do ATarget.Add(ReadMethodDecl(AText, APos));
end;

procedure ReadMeta(const AText: string; var APos: Integer;
                   AIface: TUnitInterface);
var
  C, I: Integer;
begin
  AIface.SourceFile      := ReadLpstrAt(AText, APos);
  AIface.SourceHash      := ReadLpstrAt(AText, APos);
  AIface.CompilerVersion := ReadLpstrAt(AText, APos);
  C := DecodeCount(AText, APos);
  for I := 1 to C do
    AIface.UsedUnits.Add(ReadLpstrAt(AText, APos));
  if ReadTag(AText, APos) <> 'END' then
    raise EIfaceFormatError.Create('META block: missing END marker');
end;

procedure ReadProcPayload(const AText: string; var APos: Integer;
                          AEntry: TTypeEntry);
var
  Def:      TProceduralTypeDef;
  Pc, J:    Integer;
  Param:    TMethodParam;
  FlagsStr: string;
begin
  Def := TProceduralTypeDef.Create;
  Def.IsFunction     := DecodeBool(AText, APos);
  Def.IsMethodPtr    := DecodeBool(AText, APos);
  Def.ReturnTypeName := ReadLpstrAt(AText, APos);
  Pc := DecodeCount(AText, APos);
  for J := 1 to Pc do
  begin
    Param := TMethodParam.Create;
    Param.ParamName := ReadLpstrAt(AText, APos);
    Param.TypeName  := ReadLpstrAt(AText, APos);
    FlagsStr := ReadLpstrAt(AText, APos);
    DecodeParamFlags(StrToInt(FlagsStr), Param);
    Def.Params.Add(Param);
  end;
  AEntry.Def := Def;
end;

procedure ReadInterfacePayload(const AText: string; var APos: Integer;
                               AEntry: TTypeEntry);
var
  Def: TInterfaceTypeDef;
begin
  Def := TInterfaceTypeDef.Create;
  Def.ParentName := ReadLpstrAt(AText, APos);
  ReadMethodDeclList(AText, APos, Def.Methods);
  AEntry.Def := Def;
end;

procedure ReadTypes(const AText: string; var APos: Integer;
                    AIface: TUnitInterface);
var
  Count:    Integer;
  I:        Integer;
  Kind:     string;
  Name:     string;
  Payload:  string;
  Entry:    TTypeEntry;
  EnumDef:  TEnumTypeDef;
  SetDef:   TSetTypeDef;
  AliasDef: TTypeAliasDef;
begin
  Count := ReadDecimalAt(AText, APos);
  for I := 1 to Count do
  begin
    Kind  := ReadLpstrAt(AText, APos);
    Name  := ReadLpstrAt(AText, APos);
    Entry := TTypeEntry.Create;
    Entry.Name := Name;

    if Kind = 'enum' then
    begin
      Payload := ReadLpstrAt(AText, APos);
      EnumDef := TEnumTypeDef.Create;
      SplitMembers(Payload, EnumDef.Members);
      Entry.Def := EnumDef;
    end
    else if Kind = 'set' then
    begin
      Payload := ReadLpstrAt(AText, APos);
      SetDef := TSetTypeDef.Create;
      SetDef.BaseTypeName := Payload;
      Entry.Def := SetDef;
    end
    else if Kind = 'alias' then
    begin
      Payload := ReadLpstrAt(AText, APos);
      AliasDef := TTypeAliasDef.Create;
      AliasDef.TypeName := Payload;
      Entry.Def := AliasDef;
    end
    else if Kind = 'record' then
      ReadRecordPayload(AText, APos, Entry)
    else if Kind = 'class' then
      ReadClassPayload(AText, APos, Entry)
    else if Kind = 'interface' then
      ReadInterfacePayload(AText, APos, Entry)
    else if Kind = 'proc' then
      ReadProcPayload(AText, APos, Entry)
    else
    begin
      Entry.Free;
      raise EIfaceFormatError.Create('TYPE block: unknown kind ''' + Kind + '''');
    end;
    AIface.AddType(Entry);
  end;
  if ReadTag(AText, APos) <> 'END' then
    raise EIfaceFormatError.Create('TYPE block: missing END marker');
end;

{ Inverse of EncodeParamFlags. }
procedure DecodeParamFlags(AFlags: Integer; AParam: TMethodParam);
begin
  AParam.IsVarParam   := (AFlags and 1) <> 0;
  AParam.IsConstParam := (AFlags and 2) <> 0;
  AParam.IsOpenArray  := (AFlags and 4) <> 0;
end;

procedure ReadRoutines(const AText: string; var APos: Integer;
                       AIface: TUnitInterface);
var
  Count:    Integer;
  I, J:     Integer;
  PCount:   Integer;
  R:        TRoutineSig;
  RefStr:   string;
  RefUnit:  string;
  RefType:  string;
  IsFnStr:  string;
  Param:    TMethodParam;
  FlagsStr: string;
begin
  Count := ReadDecimalAt(AText, APos);
  for I := 1 to Count do
  begin
    R := TRoutineSig.Create;
    R.Name        := ReadLpstrAt(AText, APos);
    IsFnStr       := ReadLpstrAt(AText, APos);
    R.IsFunction  := IsFnStr <> '0';
    RefStr        := ReadLpstrAt(AText, APos);
    DecodeQualRef(RefStr, RefUnit, RefType);
    R.ReturnType  := MakeQualRef(RefUnit, RefType);
    R.ResolvedQbeName := ReadLpstrAt(AText, APos);
    PCount := StrToInt(ReadLpstrAt(AText, APos));
    for J := 1 to PCount do
    begin
      Param := TMethodParam.Create;
      Param.ParamName := ReadLpstrAt(AText, APos);
      Param.TypeName  := ReadLpstrAt(AText, APos);
      FlagsStr := ReadLpstrAt(AText, APos);
      DecodeParamFlags(StrToInt(FlagsStr), Param);
      R.Params.Add(Param);
    end;
    AIface.AddRoutine(R);
  end;
  if ReadTag(AText, APos) <> 'END' then
    raise EIfaceFormatError.Create('ROUT block: missing END marker');
end;

function ReadUnitInterface(const AText: string): TUnitInterface;
var
  Cur:    Integer;
  UName:  string;
  Tag:    string;
begin
  Cur := 0;  { 0-based cursor }
  ReadHeader(AText, Cur);
  UName := ReadLpstrAt(AText, Cur);
  Result := TUnitInterface.Create(UName);
  try
    while Cur < Length(AText) do
    begin
      SkipWhitespace(AText, Cur);
      if Cur >= Length(AText) then Break;
      Tag := ReadTag(AText, Cur);
      if      Tag = 'CONST' then ReadConsts  (AText, Cur, Result)
      else if Tag = 'VAR'   then ReadVars    (AText, Cur, Result)
      else if Tag = 'TYPE'  then ReadTypes   (AText, Cur, Result)
      else if Tag = 'ROUT'  then ReadRoutines(AText, Cur, Result)
      else if Tag = 'META'  then ReadMeta    (AText, Cur, Result)
      else if Tag = ''      then Break
      else
        raise EIfaceFormatError.Create(Format(
          'unknown record tag ''%s'' at position %d', [Tag, Cur]));
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure WriteUnitInterfaceToFile(AIface: TUnitInterface; const APath: string);
var
  Bytes: string;
  FOut:  TFileOutputStream;
begin
  Bytes := WriteUnitInterface(AIface);
  FOut := TFileOutputStream.Create(APath);
  try
    if Length(Bytes) > 0 then
      FOut.Write(PChar(Bytes), Length(Bytes));
  finally
    FOut.Close;
    FOut.Free;
  end;
end;

function ReadUnitInterfaceFromFile(const APath: string): TUnitInterface;
var
  Bytes: string;
  FIn:   TFileInputStream;
begin
  FIn := TFileInputStream.Create(APath);
  try
    SetLength(Bytes, Integer(FIn.Size));
    if Length(Bytes) > 0 then
      FIn.Read(PChar(Bytes), Length(Bytes));
  finally
    FIn.Free;
  end;
  Result := ReadUnitInterface(Bytes);
end;

end.
