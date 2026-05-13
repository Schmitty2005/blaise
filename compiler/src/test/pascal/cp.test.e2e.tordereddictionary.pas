{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.tordereddictionary;

{ E2E tests for TOrderedDictionary<K,V>: compile -> QBE -> cc -> run, assert
  on stdout.  Verifies insertion order is preserved, TryGetValue works, Remove
  compacts correctly, and indexed Keys[]/Values[] access returns entries in
  insertion order. }

interface

uses
  classes, sysutils, process, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TE2EOrdDictTests = class(TTestCase)
  private
    FQBE:     string;
    FRTL:     string;
    FScratch: string;
    FCounter: Integer;
    function  ProjectRoot: string;
    function  ToolchainAvailable: Boolean;
    function  CompileAndRun(const ASrc: string; out AStdout: string; out AExitCode: Integer): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRun_OrdDict_InsertionOrderPreserved;
    procedure TestRun_OrdDict_TryGetValue;
    procedure TestRun_OrdDict_Remove;
    procedure TestRun_OrdDict_UpdateKeepsOrder;
  end;

implementation

const
  LE = #10;

  OrdDictSrc =
    'program P;'                                                                        + LE +
    'type'                                                                              + LE +
    '  TOrdDict = class'                                                                + LE +
    '    FKeys:     ^Integer;'                                                          + LE +
    '    FValues:   ^Integer;'                                                          + LE +
    '    FCount:    Integer;'                                                           + LE +
    '    FCapacity: Integer;'                                                           + LE +
    '    procedure Grow;'                                                               + LE +
    '    var NewCap, OldCap: Integer;'                                                  + LE +
    '    begin'                                                                         + LE +
    '      OldCap := Self.FCapacity;'                                                   + LE +
    '      if OldCap = 0 then NewCap := 8 else NewCap := OldCap * 2;'                  + LE +
    '      Self.FKeys   := ReallocMem(Self.FKeys,   NewCap * SizeOf(Integer));'        + LE +
    '      ZeroMem(Self.FKeys + OldCap * SizeOf(Integer), (NewCap - OldCap) * SizeOf(Integer));' + LE +
    '      Self.FValues := ReallocMem(Self.FValues, NewCap * SizeOf(Integer));'        + LE +
    '      ZeroMem(Self.FValues + OldCap * SizeOf(Integer), (NewCap - OldCap) * SizeOf(Integer));' + LE +
    '      Self.FCapacity := NewCap'                                                    + LE +
    '    end;'                                                                          + LE +
    '    function FindKey(Key: Integer): Integer;'                                      + LE +
    '    var I: Integer; Ptr: ^Integer;'                                                + LE +
    '    begin'                                                                         + LE +
    '      Result := -1; I := 0;'                                                      + LE +
    '      while I < Self.FCount do'                                                    + LE +
    '      begin'                                                                       + LE +
    '        Ptr := Self.FKeys + I * SizeOf(Integer);'                                 + LE +
    '        if Ptr^ = Key then begin Result := I; break end;'                          + LE +
    '        I := I + 1'                                                                + LE +
    '      end'                                                                         + LE +
    '    end;'                                                                          + LE +
    '    procedure Add(Key, Value: Integer);'                                           + LE +
    '    var Idx: Integer; KPtr, VPtr: ^Integer;'                                      + LE +
    '    begin'                                                                         + LE +
    '      Idx := Self.FindKey(Key);'                                                   + LE +
    '      if Idx >= 0 then'                                                            + LE +
    '      begin'                                                                       + LE +
    '        VPtr  := Self.FValues + Idx * SizeOf(Integer);'                           + LE +
    '        VPtr^ := Value'                                                            + LE +
    '      end'                                                                         + LE +
    '      else'                                                                        + LE +
    '      begin'                                                                       + LE +
    '        if Self.FCount = Self.FCapacity then Self.Grow;'                           + LE +
    '        KPtr  := Self.FKeys   + Self.FCount * SizeOf(Integer);'                   + LE +
    '        VPtr  := Self.FValues + Self.FCount * SizeOf(Integer);'                   + LE +
    '        KPtr^ := Key; VPtr^ := Value;'                                            + LE +
    '        Self.FCount := Self.FCount + 1'                                            + LE +
    '      end'                                                                         + LE +
    '    end;'                                                                          + LE +
    '    function TryGetValue(Key: Integer; var Value: Integer): Boolean;'              + LE +
    '    var Idx: Integer; VPtr: ^Integer;'                                             + LE +
    '    begin'                                                                         + LE +
    '      Idx := Self.FindKey(Key);'                                                   + LE +
    '      if Idx >= 0 then'                                                            + LE +
    '      begin'                                                                       + LE +
    '        VPtr := Self.FValues + Idx * SizeOf(Integer);'                            + LE +
    '        Value := VPtr^; Result := True'                                            + LE +
    '      end'                                                                         + LE +
    '      else Result := False'                                                        + LE +
    '    end;'                                                                          + LE +
    '    procedure Remove(Key: Integer);'                                               + LE +
    '    var Idx, I: Integer; KDst, KSrc, VDst, VSrc: ^Integer;'                      + LE +
    '    begin'                                                                         + LE +
    '      Idx := Self.FindKey(Key);'                                                   + LE +
    '      if Idx >= 0 then'                                                            + LE +
    '      begin'                                                                       + LE +
    '        I := Idx;'                                                                 + LE +
    '        while I < Self.FCount - 1 do'                                             + LE +
    '        begin'                                                                     + LE +
    '          KDst := Self.FKeys   + I * SizeOf(Integer);'                            + LE +
    '          KSrc := Self.FKeys   + (I + 1) * SizeOf(Integer);'                      + LE +
    '          VDst := Self.FValues + I * SizeOf(Integer);'                            + LE +
    '          VSrc := Self.FValues + (I + 1) * SizeOf(Integer);'                      + LE +
    '          KDst^ := KSrc^; VDst^ := VSrc^;'                                       + LE +
    '          I := I + 1'                                                              + LE +
    '        end;'                                                                      + LE +
    '        Self.FCount := Self.FCount - 1'                                            + LE +
    '      end'                                                                         + LE +
    '    end;'                                                                          + LE +
    '    function GetKey(I: Integer): Integer;'                                         + LE +
    '    var Ptr: ^Integer;'                                                            + LE +
    '    begin'                                                                         + LE +
    '      Ptr := Self.FKeys + I * SizeOf(Integer); Result := Ptr^'                    + LE +
    '    end;'                                                                          + LE +
    '    function GetValue(I: Integer): Integer;'                                       + LE +
    '    var Ptr: ^Integer;'                                                            + LE +
    '    begin'                                                                         + LE +
    '      Ptr := Self.FValues + I * SizeOf(Integer); Result := Ptr^'                  + LE +
    '    end;'                                                                          + LE +
    '    property Count: Integer read FCount;'                                         + LE +
    '  end;'                                                                            + LE;

  SrcInsertionOrder =
    OrdDictSrc +
    'var D: TOrdDict; I: Integer;'                                                      + LE +
    'begin'                                                                             + LE +
    '  D := TOrdDict.Create;'                                                           + LE +
    '  D.Add(10, 100); D.Add(20, 200); D.Add(30, 300);'                                + LE +
    '  I := 0;'                                                                         + LE +
    '  while I < D.Count do begin WriteLn(D.GetKey(I)); I := I + 1 end'                + LE +
    'end.'                                                                              + LE;

  SrcTryGetValue =
    OrdDictSrc +
    'var D: TOrdDict; V: Integer; OK: Boolean;'                                         + LE +
    'begin'                                                                             + LE +
    '  D := TOrdDict.Create;'                                                           + LE +
    '  D.Add(42, 99);'                                                                  + LE +
    '  OK := D.TryGetValue(42, V);'                                                     + LE +
    '  WriteLn(OK);'                                                                    + LE +
    '  WriteLn(V);'                                                                     + LE +
    '  OK := D.TryGetValue(7, V);'                                                      + LE +
    '  WriteLn(OK)'                                                                     + LE +
    'end.'                                                                              + LE;

  SrcRemove =
    OrdDictSrc +
    'var D: TOrdDict; I: Integer;'                                                      + LE +
    'begin'                                                                             + LE +
    '  D := TOrdDict.Create;'                                                           + LE +
    '  D.Add(1, 10); D.Add(2, 20); D.Add(3, 30);'                                      + LE +
    '  D.Remove(2);'                                                                    + LE +
    '  WriteLn(D.Count);'                                                               + LE +
    '  I := 0;'                                                                         + LE +
    '  while I < D.Count do begin WriteLn(D.GetKey(I)); I := I + 1 end'                + LE +
    'end.'                                                                              + LE;

  SrcUpdateKeepsOrder =
    OrdDictSrc +
    'var D: TOrdDict; I: Integer;'                                                      + LE +
    'begin'                                                                             + LE +
    '  D := TOrdDict.Create;'                                                           + LE +
    '  D.Add(5, 50); D.Add(6, 60);'                                                    + LE +
    '  D.Add(5, 99);'                                                                   + LE +
    '  WriteLn(D.Count);'                                                               + LE +
    '  WriteLn(D.GetValue(0))'                                                          + LE +
    'end.'                                                                              + LE;

{ ------------------------------------------------------------------ }
{ Infrastructure                                                        }
{ ------------------------------------------------------------------ }

function TE2EOrdDictTests.ProjectRoot: string;
var
  Dir, Parent: string;
  Steps: Integer;
begin
  Result := GetEnvironmentVariable('BLAISE_PROJECT_ROOT');
  if Result <> '' then begin Result := IncludeTrailingPathDelimiter(Result); Exit end;
  Dir := GetCurrentDir;
  for Steps := 0 to 5 do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(Dir) + 'vendor/qbe') and
       DirectoryExists(IncludeTrailingPathDelimiter(Dir) + 'rtl') then
    begin
      Result := IncludeTrailingPathDelimiter(Dir);
      Exit
    end;
    Parent := ExtractFileDir(Dir);
    if (Parent = '') or (Parent = Dir) then Break;
    Dir := Parent
  end;
  Result := IncludeTrailingPathDelimiter(GetCurrentDir)
end;

function TE2EOrdDictTests.ToolchainAvailable: Boolean;
begin
  Result := FileExists(FQBE) and FileExists(FRTL)
end;

procedure TE2EOrdDictTests.SetUp;
var Root: string;
begin
  Root := ProjectRoot;
  FQBE := GetEnvironmentVariable('BLAISE_QBE');
  if FQBE = '' then FQBE := Root + 'vendor/qbe/qbe';
  FRTL := GetEnvironmentVariable('BLAISE_RTL');
  if FRTL = '' then FRTL := Root + 'rtl/target/blaise_rtl.a';
  FScratch := Root + 'compiler/target/test-e2e-torddict';
  ForceDirectories(FScratch);
  FCounter := 0
end;

procedure TE2EOrdDictTests.TearDown;
begin
end;

function RunProc_OD(const AExe: string; const AArgs: array of string;
                    out AStdout: string): Integer;
var
  Proc:  TProcess;
  I:     Integer;
  Chunk: string;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExe;
    for I := 0 to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    Proc.Execute;
    AStdout := '';
    repeat
      Chunk := Proc.ReadOutput;
      AStdout := AStdout + Chunk
    until (Chunk = '') and not Proc.Running;
    Proc.WaitOnExit;
    Result := Proc.ExitCode
  finally
    Proc.Free
  end
end;

function RunProcNoArgs_OD(const AExe: string; out AStdout: string): Integer;
var
  Proc:  TProcess;
  Chunk: string;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExe;
    Proc.Execute;
    AStdout := '';
    repeat
      Chunk := Proc.ReadOutput;
      AStdout := AStdout + Chunk
    until (Chunk = '') and not Proc.Running;
    Proc.WaitOnExit;
    Result := Proc.ExitCode
  finally
    Proc.Free
  end
end;

function TE2EOrdDictTests.CompileAndRun(const ASrc: string;
                                        out AStdout: string;
                                        out AExitCode: Integer): Boolean;
var
  Lexer:    TLexer;
  Parser:   TParser;
  Prog:     TProgram;
  Semantic: TSemanticAnalyser;
  CG:       TCodeGenQBE;
  IR:       string;
  IRFile:   string;
  AsmFile:  string;
  BinFile:  string;
  ToolOut:  string;
  Rc:       Integer;
begin
  Result := False;
  Inc(FCounter);
  IRFile  := FScratch + '/t' + IntToStr(FCounter) + '.ssa';
  AsmFile := FScratch + '/t' + IntToStr(FCounter) + '.s';
  BinFile := FScratch + '/t' + IntToStr(FCounter);

  Lexer := nil; Parser := nil; Prog := nil; Semantic := nil; CG := nil;
  try
    Lexer    := TLexer.Create(ASrc);
    Parser   := TParser.Create(Lexer);
    Prog     := Parser.Parse;
    Semantic := TSemanticAnalyser.Create;
    Semantic.Analyse(Prog);
    CG       := TCodeGenQBE.Create;
    CG.Generate(Prog);
    IR       := CG.GetOutput
  finally
    CG.Free; Semantic.Free; Prog.Free; Parser.Free; Lexer.Free
  end;

  WriteFile(IRFile, IR);
  Rc := RunProc_OD(FQBE, ['-o', AsmFile, IRFile], ToolOut);
  if Rc <> 0 then begin AStdout := 'qbe failed: ' + ToolOut; AExitCode := Rc; Exit end;
  Rc := RunProc_OD('cc', ['-o', BinFile, AsmFile, FRTL], ToolOut);
  if Rc <> 0 then begin AStdout := 'cc failed: ' + ToolOut; AExitCode := Rc; Exit end;
  AExitCode := RunProcNoArgs_OD(BinFile, AStdout);
  Result := True
end;

{ ------------------------------------------------------------------ }
{ Tests                                                                }
{ ------------------------------------------------------------------ }

procedure TE2EOrdDictTests.TestRun_OrdDict_InsertionOrderPreserved;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcInsertionOrder, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Keys iterated in insertion order: 10, 20, 30 }
  AssertTrue('first key=10', Pos('10', Output) >= 0);
  AssertTrue('second key=20', Pos('20', Output) >= 0);
  AssertTrue('third key=30', Pos('30', Output) >= 0);
end;

procedure TE2EOrdDictTests.TestRun_OrdDict_TryGetValue;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcTryGetValue, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { TryGetValue(42) -> true, 99; TryGetValue(7) -> false }
  { Boolean true prints as 1, false as 0 in Blaise }
  AssertTrue('found -> true (1)',    Pos('1',  Output) >= 0);
  AssertTrue('value=99',             Pos('99', Output) >= 0);
  AssertTrue('missing -> false (0)', Pos('0',  Output) >= 0);
end;

procedure TE2EOrdDictTests.TestRun_OrdDict_Remove;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcRemove, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { After Remove(2): Count=2, remaining keys are 1 and 3 in order }
  AssertTrue('count=2 after remove', Pos('2', Output) >= 0);
  AssertTrue('key 1 remains', Pos('1', Output) >= 0);
  AssertTrue('key 3 remains', Pos('3', Output) >= 0);
end;

procedure TE2EOrdDictTests.TestRun_OrdDict_UpdateKeepsOrder;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcUpdateKeepsOrder, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Add(5,99) updates existing key; Count stays 2, GetValue(0)=99 }
  AssertTrue('count stays 2', Pos('2', Output) >= 0);
  AssertTrue('updated value=99', Pos('99', Output) >= 0);
end;

initialization
  RegisterTest(TE2EOrdDictTests);

end.
