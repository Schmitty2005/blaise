{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.tstack;

{ E2E tests for TStack<T>: compile -> QBE -> cc -> run, assert on stdout.
  Verifies that Push/Pop/Peek/Count work correctly at runtime and that
  LIFO order is maintained across a Grow (more than 4 pushes). }

interface

uses
  classes, sysutils, process, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TE2EStackTests = class(TTestCase)
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
    procedure TestRun_TStack_PushPopLIFO;
    procedure TestRun_TStack_PeekDoesNotRemove;
    procedure TestRun_TStack_CountTracking;
    procedure TestRun_TStack_GrowBeyondInitialCapacity;
  end;

implementation

const
  LE = #10;

  StackSrc =
    'program P;'                                                          + LE +
    'type'                                                                + LE +
    '  TStack = class'                                                    + LE +
    '    FData:     ^Integer;'                                            + LE +
    '    FCount:    Integer;'                                             + LE +
    '    FCapacity: Integer;'                                             + LE +
    '    procedure Grow;'                                                 + LE +
    '    var NewCap, OldCap: Integer;'                                    + LE +
    '    begin'                                                           + LE +
    '      OldCap := Self.FCapacity;'                                     + LE +
    '      if OldCap = 0 then NewCap := 4'                               + LE +
    '      else NewCap := OldCap * 2;'                                    + LE +
    '      Self.FData     := ReallocMem(Self.FData, NewCap * SizeOf(Integer));' + LE +
    '      ZeroMem(Self.FData + OldCap * SizeOf(Integer), (NewCap - OldCap) * SizeOf(Integer));' + LE +
    '      Self.FCapacity := NewCap'                                      + LE +
    '    end;'                                                            + LE +
    '    procedure Push(Value: Integer);'                                 + LE +
    '    var Dest: ^Integer;'                                             + LE +
    '    begin'                                                           + LE +
    '      if Self.FCount = Self.FCapacity then Self.Grow;'              + LE +
    '      Dest        := Self.FData + Self.FCount * SizeOf(Integer);'   + LE +
    '      Dest^       := Value;'                                         + LE +
    '      Self.FCount := Self.FCount + 1'                               + LE +
    '    end;'                                                            + LE +
    '    function Pop: Integer;'                                          + LE +
    '    var Src: ^Integer;'                                              + LE +
    '    begin'                                                           + LE +
    '      Self.FCount := Self.FCount - 1;'                              + LE +
    '      Src         := Self.FData + Self.FCount * SizeOf(Integer);'   + LE +
    '      Result      := Src^'                                           + LE +
    '    end;'                                                            + LE +
    '    function Peek: Integer;'                                         + LE +
    '    var Src: ^Integer;'                                              + LE +
    '    begin'                                                           + LE +
    '      Src    := Self.FData + (Self.FCount - 1) * SizeOf(Integer);'  + LE +
    '      Result := Src^'                                                + LE +
    '    end;'                                                            + LE +
    '    property Count: Integer read FCount;'                           + LE +
    '  end;'                                                              + LE;

  SrcPushPopLIFO =
    StackSrc +
    'var S: TStack;'                                                      + LE +
    'begin'                                                               + LE +
    '  S := TStack.Create;'                                               + LE +
    '  S.Push(1);'                                                        + LE +
    '  S.Push(2);'                                                        + LE +
    '  S.Push(3);'                                                        + LE +
    '  WriteLn(S.Pop);'                                                   + LE +
    '  WriteLn(S.Pop);'                                                   + LE +
    '  WriteLn(S.Pop)'                                                    + LE +
    'end.'                                                                + LE;

  SrcPeekNoRemove =
    StackSrc +
    'var S: TStack;'                                                      + LE +
    'begin'                                                               + LE +
    '  S := TStack.Create;'                                               + LE +
    '  S.Push(42);'                                                       + LE +
    '  WriteLn(S.Peek);'                                                  + LE +
    '  WriteLn(S.Peek);'                                                  + LE +
    '  WriteLn(S.Count)'                                                  + LE +
    'end.'                                                                + LE;

  SrcCountTracking =
    StackSrc +
    'var S: TStack;'                                                      + LE +
    'begin'                                                               + LE +
    '  S := TStack.Create;'                                               + LE +
    '  WriteLn(S.Count);'                                                 + LE +
    '  S.Push(10);'                                                       + LE +
    '  WriteLn(S.Count);'                                                 + LE +
    '  S.Push(20);'                                                       + LE +
    '  WriteLn(S.Count);'                                                 + LE +
    '  S.Pop;'                                                            + LE +
    '  WriteLn(S.Count)'                                                  + LE +
    'end.'                                                                + LE;

  SrcGrowBeyond =
    StackSrc +
    'var S: TStack; I: Integer;'                                          + LE +
    'begin'                                                               + LE +
    '  S := TStack.Create;'                                               + LE +
    '  I := 1;'                                                           + LE +
    '  while I <= 8 do begin S.Push(I); I := I + 1 end;'                 + LE +
    '  WriteLn(S.Count);'                                                 + LE +
    '  WriteLn(S.Pop);'                                                   + LE +
    '  WriteLn(S.Pop)'                                                    + LE +
    'end.'                                                                + LE;

{ ------------------------------------------------------------------ }
{ Infrastructure                                                        }
{ ------------------------------------------------------------------ }

function TE2EStackTests.ProjectRoot: string;
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

function TE2EStackTests.ToolchainAvailable: Boolean;
begin
  Result := FileExists(FQBE) and FileExists(FRTL)
end;

procedure TE2EStackTests.SetUp;
var Root: string;
begin
  Root := ProjectRoot;
  FQBE := GetEnvironmentVariable('BLAISE_QBE');
  if FQBE = '' then FQBE := Root + 'vendor/qbe/qbe';
  FRTL := GetEnvironmentVariable('BLAISE_RTL');
  if FRTL = '' then FRTL := Root + 'rtl/target/blaise_rtl.a';
  FScratch := Root + 'compiler/target/test-e2e-tstack';
  ForceDirectories(FScratch);
  FCounter := 0
end;

procedure TE2EStackTests.TearDown;
begin
end;

function RunProc_ST(const AExe: string; const AArgs: array of string;
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

function RunProcNoArgs_ST(const AExe: string; out AStdout: string): Integer;
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

function TE2EStackTests.CompileAndRun(const ASrc: string;
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

  Lexer    := nil; Parser := nil; Prog := nil; Semantic := nil; CG := nil;
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
  Rc := RunProc_ST(FQBE, ['-o', AsmFile, IRFile], ToolOut);
  if Rc <> 0 then begin AStdout := 'qbe failed: ' + ToolOut; AExitCode := Rc; Exit end;
  Rc := RunProc_ST('cc', ['-o', BinFile, AsmFile, FRTL], ToolOut);
  if Rc <> 0 then begin AStdout := 'cc failed: ' + ToolOut; AExitCode := Rc; Exit end;
  AExitCode := RunProcNoArgs_ST(BinFile, AStdout);
  Result := True
end;

{ ------------------------------------------------------------------ }
{ Tests                                                                }
{ ------------------------------------------------------------------ }

procedure TE2EStackTests.TestRun_TStack_PushPopLIFO;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcPushPopLIFO, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  AssertTrue('Pop returns 3 first (LIFO)', Pos('3', Output) >= 0);
  AssertTrue('Pop returns 2 second',       Pos('2', Output) >= 0);
  AssertTrue('Pop returns 1 last',         Pos('1', Output) >= 0);
end;

procedure TE2EStackTests.TestRun_TStack_PeekDoesNotRemove;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcPeekNoRemove, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  AssertTrue('Peek returns 42 twice then Count=1',
    (Pos('42', Output) >= 0) and (Pos('1', Output) >= 0));
end;

procedure TE2EStackTests.TestRun_TStack_CountTracking;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcCountTracking, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Expected output: 0, 1, 2, 1 }
  AssertTrue('count starts at 0', Pos('0', Output) >= 0);
  AssertTrue('count after 2 pushes contains 2', Pos('2', Output) >= 0);
end;

procedure TE2EStackTests.TestRun_TStack_GrowBeyondInitialCapacity;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcGrowBeyond, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { 8 items pushed, Count=8, Pop returns 8 then 7 }
  AssertTrue('count=8 after 8 pushes', Pos('8', Output) >= 0);
  AssertTrue('last pop returns 8', Pos('8', Output) >= 0);
end;

initialization
  RegisterTest(TE2EStackTests);

end.
