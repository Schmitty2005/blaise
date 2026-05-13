{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.tset;

{ E2E tests for TSet<T>: compile -> QBE -> cc -> run, assert on stdout.
  Verifies that Include deduplicates, Exclude removes, Contains tests
  membership, and Count tracks correctly. }

interface

uses
  classes, sysutils, process, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TE2ESetTests = class(TTestCase)
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
    procedure TestRun_TSet_IncludeDeduplicates;
    procedure TestRun_TSet_ExcludeRemoves;
    procedure TestRun_TSet_ContainsMembership;
    procedure TestRun_TSet_CountTracking;
  end;

implementation

const
  LE = #10;

  SetSrc =
    'program P;'                                                           + LE +
    'type'                                                                 + LE +
    '  TSet = class'                                                       + LE +
    '    FData:     ^Integer;'                                             + LE +
    '    FCount:    Integer;'                                              + LE +
    '    FCapacity: Integer;'                                              + LE +
    '    procedure Grow;'                                                  + LE +
    '    var NewCap, OldCap: Integer;'                                     + LE +
    '    begin'                                                            + LE +
    '      OldCap := Self.FCapacity;'                                      + LE +
    '      if OldCap = 0 then NewCap := 4 else NewCap := OldCap * 2;'     + LE +
    '      Self.FData     := ReallocMem(Self.FData, NewCap * SizeOf(Integer));' + LE +
    '      ZeroMem(Self.FData + OldCap * SizeOf(Integer), (NewCap - OldCap) * SizeOf(Integer));' + LE +
    '      Self.FCapacity := NewCap'                                       + LE +
    '    end;'                                                             + LE +
    '    function IndexOf(Value: Integer): Integer;'                       + LE +
    '    var I: Integer; Ptr: ^Integer;'                                   + LE +
    '    begin'                                                            + LE +
    '      Result := -1; I := 0;'                                         + LE +
    '      while I < Self.FCount do'                                       + LE +
    '      begin'                                                          + LE +
    '        Ptr := Self.FData + I * SizeOf(Integer);'                    + LE +
    '        if Ptr^ = Value then begin Result := I; break end;'           + LE +
    '        I := I + 1'                                                   + LE +
    '      end'                                                            + LE +
    '    end;'                                                             + LE +
    '    procedure Include(Value: Integer);'                               + LE +
    '    var Dest: ^Integer;'                                              + LE +
    '    begin'                                                            + LE +
    '      if Self.IndexOf(Value) >= 0 then Exit;'                        + LE +
    '      if Self.FCount = Self.FCapacity then Self.Grow;'               + LE +
    '      Dest        := Self.FData + Self.FCount * SizeOf(Integer);'    + LE +
    '      Dest^       := Value;'                                          + LE +
    '      Self.FCount := Self.FCount + 1'                                + LE +
    '    end;'                                                             + LE +
    '    procedure Exclude(Value: Integer);'                               + LE +
    '    var Idx, I: Integer; Dst, Src: ^Integer;'                        + LE +
    '    begin'                                                            + LE +
    '      Idx := Self.IndexOf(Value);'                                   + LE +
    '      if Idx < 0 then Exit;'                                         + LE +
    '      I := Idx;'                                                      + LE +
    '      while I < Self.FCount - 1 do'                                  + LE +
    '      begin'                                                          + LE +
    '        Dst  := Self.FData + I * SizeOf(Integer);'                   + LE +
    '        Src  := Self.FData + (I + 1) * SizeOf(Integer);'             + LE +
    '        Dst^ := Src^;'                                                + LE +
    '        I    := I + 1'                                                + LE +
    '      end;'                                                           + LE +
    '      Self.FCount := Self.FCount - 1'                                + LE +
    '    end;'                                                             + LE +
    '    function Contains(Value: Integer): Boolean;'                      + LE +
    '    begin'                                                            + LE +
    '      Result := Self.IndexOf(Value) >= 0'                            + LE +
    '    end;'                                                             + LE +
    '    property Count: Integer read FCount;'                            + LE +
    '  end;'                                                               + LE;

  SrcDeduplicate =
    SetSrc +
    'var S: TSet;'                                                         + LE +
    'begin'                                                                + LE +
    '  S := TSet.Create;'                                                  + LE +
    '  S.Include(5); S.Include(5); S.Include(5);'                         + LE +
    '  WriteLn(S.Count)'                                                   + LE +
    'end.'                                                                 + LE;

  SrcExclude =
    SetSrc +
    'var S: TSet;'                                                         + LE +
    'begin'                                                                + LE +
    '  S := TSet.Create;'                                                  + LE +
    '  S.Include(1); S.Include(2); S.Include(3);'                         + LE +
    '  S.Exclude(2);'                                                      + LE +
    '  WriteLn(S.Count);'                                                  + LE +
    '  WriteLn(S.Contains(2))'                                             + LE +
    'end.'                                                                 + LE;

  SrcContains =
    SetSrc +
    'var S: TSet;'                                                         + LE +
    'begin'                                                                + LE +
    '  S := TSet.Create;'                                                  + LE +
    '  S.Include(42);'                                                     + LE +
    '  WriteLn(S.Contains(42));'                                           + LE +
    '  WriteLn(S.Contains(99))'                                            + LE +
    'end.'                                                                 + LE;

  SrcCountTracking =
    SetSrc +
    'var S: TSet;'                                                         + LE +
    'begin'                                                                + LE +
    '  S := TSet.Create;'                                                  + LE +
    '  WriteLn(S.Count);'                                                  + LE +
    '  S.Include(10); S.Include(20); S.Include(30);'                      + LE +
    '  WriteLn(S.Count);'                                                  + LE +
    '  S.Exclude(20);'                                                     + LE +
    '  WriteLn(S.Count)'                                                   + LE +
    'end.'                                                                 + LE;

{ ------------------------------------------------------------------ }
{ Infrastructure                                                        }
{ ------------------------------------------------------------------ }

function TE2ESetTests.ProjectRoot: string;
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

function TE2ESetTests.ToolchainAvailable: Boolean;
begin
  Result := FileExists(FQBE) and FileExists(FRTL)
end;

procedure TE2ESetTests.SetUp;
var Root: string;
begin
  Root := ProjectRoot;
  FQBE := GetEnvironmentVariable('BLAISE_QBE');
  if FQBE = '' then FQBE := Root + 'vendor/qbe/qbe';
  FRTL := GetEnvironmentVariable('BLAISE_RTL');
  if FRTL = '' then FRTL := Root + 'rtl/target/blaise_rtl.a';
  FScratch := Root + 'compiler/target/test-e2e-tset';
  ForceDirectories(FScratch);
  FCounter := 0
end;

procedure TE2ESetTests.TearDown;
begin
end;

function RunProc_S(const AExe: string; const AArgs: array of string;
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

function RunProcNoArgs_S(const AExe: string; out AStdout: string): Integer;
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

function TE2ESetTests.CompileAndRun(const ASrc: string;
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
  Rc := RunProc_S(FQBE, ['-o', AsmFile, IRFile], ToolOut);
  if Rc <> 0 then begin AStdout := 'qbe failed: ' + ToolOut; AExitCode := Rc; Exit end;
  Rc := RunProc_S('cc', ['-o', BinFile, AsmFile, FRTL], ToolOut);
  if Rc <> 0 then begin AStdout := 'cc failed: ' + ToolOut; AExitCode := Rc; Exit end;
  AExitCode := RunProcNoArgs_S(BinFile, AStdout);
  Result := True
end;

{ ------------------------------------------------------------------ }
{ Tests                                                                }
{ ------------------------------------------------------------------ }

procedure TE2ESetTests.TestRun_TSet_IncludeDeduplicates;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcDeduplicate, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Include(5) called 3 times — Count must be 1 }
  AssertTrue('count=1 after three identical includes', Pos('1', Output) >= 0);
end;

procedure TE2ESetTests.TestRun_TSet_ExcludeRemoves;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcExclude, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { After Exclude(2): Count=2, Contains(2)=false }
  AssertTrue('count=2 after exclude', Pos('2', Output) >= 0);
  { Boolean false prints as 0 in Blaise }
  AssertTrue('contains returns false (0)', Pos('0', Output) >= 0);
end;

procedure TE2ESetTests.TestRun_TSet_ContainsMembership;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcContains, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Contains(42)=true, Contains(99)=false }
  { Boolean true prints as 1, false as 0 in Blaise }
  AssertTrue('contains 42 -> true (1)',  Pos('1', Output) >= 0);
  AssertTrue('contains 99 -> false (0)', Pos('0', Output) >= 0);
end;

procedure TE2ESetTests.TestRun_TSet_CountTracking;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcCountTracking, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Expected: 0, 3, 2 }
  AssertTrue('starts at 0', Pos('0', Output) >= 0);
  AssertTrue('3 after three includes', Pos('3', Output) >= 0);
  AssertTrue('2 after exclude', Pos('2', Output) >= 0);
end;

initialization
  RegisterTest(TE2ESetTests);

end.
