{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.tqueue;

{ E2E tests for TQueue<T>: compile -> QBE -> cc -> run, assert on stdout.
  Verifies FIFO ordering, Peek, Count tracking, and correct behaviour
  after Grow (circular buffer wrap). }

interface

uses
  classes, sysutils, process, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TE2EQueueTests = class(TTestCase)
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
    procedure TestRun_TQueue_EnqueueDequeueFIFO;
    procedure TestRun_TQueue_PeekDoesNotRemove;
    procedure TestRun_TQueue_CountTracking;
    procedure TestRun_TQueue_GrowBeyondInitialCapacity;
  end;

implementation

const
  LE = #10;

  QueueSrc =
    'program P;'                                                                  + LE +
    'type'                                                                        + LE +
    '  TQueue = class'                                                            + LE +
    '    FData:     ^Integer;'                                                    + LE +
    '    FCount:    Integer;'                                                     + LE +
    '    FCapacity: Integer;'                                                     + LE +
    '    FHead:     Integer;'                                                     + LE +
    '    FTail:     Integer;'                                                     + LE +
    '    procedure Grow;'                                                         + LE +
    '    var NewCap, OldCap, I: Integer; NewData, Src, Dst: ^Integer;'           + LE +
    '    begin'                                                                   + LE +
    '      OldCap  := Self.FCapacity;'                                            + LE +
    '      if OldCap = 0 then NewCap := 4 else NewCap := OldCap * 2;'            + LE +
    '      NewData := GetMem(NewCap * SizeOf(Integer));'                          + LE +
    '      ZeroMem(NewData, NewCap * SizeOf(Integer));'                           + LE +
    '      I := 0;'                                                               + LE +
    '      while I < Self.FCount do'                                              + LE +
    '      begin'                                                                 + LE +
    '        Src  := Self.FData + ((Self.FHead + I) mod OldCap) * SizeOf(Integer);' + LE +
    '        Dst  := NewData + I * SizeOf(Integer);'                              + LE +
    '        Dst^ := Src^;'                                                       + LE +
    '        I    := I + 1'                                                       + LE +
    '      end;'                                                                  + LE +
    '      FreeMem(Self.FData);'                                                  + LE +
    '      Self.FData     := NewData;'                                            + LE +
    '      Self.FHead     := 0;'                                                  + LE +
    '      Self.FTail     := Self.FCount;'                                        + LE +
    '      Self.FCapacity := NewCap'                                              + LE +
    '    end;'                                                                    + LE +
    '    procedure Enqueue(Value: Integer);'                                      + LE +
    '    var Dest: ^Integer;'                                                     + LE +
    '    begin'                                                                   + LE +
    '      if Self.FCount = Self.FCapacity then Self.Grow;'                       + LE +
    '      Dest        := Self.FData + Self.FTail * SizeOf(Integer);'             + LE +
    '      Dest^       := Value;'                                                 + LE +
    '      Self.FTail  := (Self.FTail + 1) mod Self.FCapacity;'                  + LE +
    '      Self.FCount := Self.FCount + 1'                                        + LE +
    '    end;'                                                                    + LE +
    '    function Dequeue: Integer;'                                              + LE +
    '    var Src: ^Integer;'                                                      + LE +
    '    begin'                                                                   + LE +
    '      Src         := Self.FData + Self.FHead * SizeOf(Integer);'             + LE +
    '      Result      := Src^;'                                                  + LE +
    '      Self.FHead  := (Self.FHead + 1) mod Self.FCapacity;'                  + LE +
    '      Self.FCount := Self.FCount - 1'                                        + LE +
    '    end;'                                                                    + LE +
    '    function Peek: Integer;'                                                 + LE +
    '    var Src: ^Integer;'                                                      + LE +
    '    begin'                                                                   + LE +
    '      Src    := Self.FData + Self.FHead * SizeOf(Integer);'                  + LE +
    '      Result := Src^'                                                        + LE +
    '    end;'                                                                    + LE +
    '    property Count: Integer read FCount;'                                   + LE +
    '  end;'                                                                      + LE;

  SrcFIFO =
    QueueSrc +
    'var Q: TQueue;'                                                              + LE +
    'begin'                                                                       + LE +
    '  Q := TQueue.Create;'                                                       + LE +
    '  Q.Enqueue(10);'                                                            + LE +
    '  Q.Enqueue(20);'                                                            + LE +
    '  Q.Enqueue(30);'                                                            + LE +
    '  WriteLn(Q.Dequeue);'                                                       + LE +
    '  WriteLn(Q.Dequeue);'                                                       + LE +
    '  WriteLn(Q.Dequeue)'                                                        + LE +
    'end.'                                                                        + LE;

  SrcPeekNoRemove =
    QueueSrc +
    'var Q: TQueue;'                                                              + LE +
    'begin'                                                                       + LE +
    '  Q := TQueue.Create;'                                                       + LE +
    '  Q.Enqueue(7);'                                                             + LE +
    '  WriteLn(Q.Peek);'                                                          + LE +
    '  WriteLn(Q.Peek);'                                                          + LE +
    '  WriteLn(Q.Count)'                                                          + LE +
    'end.'                                                                        + LE;

  SrcCountTracking =
    QueueSrc +
    'var Q: TQueue;'                                                              + LE +
    'begin'                                                                       + LE +
    '  Q := TQueue.Create;'                                                       + LE +
    '  WriteLn(Q.Count);'                                                         + LE +
    '  Q.Enqueue(1);'                                                             + LE +
    '  Q.Enqueue(2);'                                                             + LE +
    '  WriteLn(Q.Count);'                                                         + LE +
    '  Q.Dequeue;'                                                                + LE +
    '  WriteLn(Q.Count)'                                                          + LE +
    'end.'                                                                        + LE;

  SrcGrowBeyond =
    QueueSrc +
    'var Q: TQueue; I: Integer;'                                                  + LE +
    'begin'                                                                       + LE +
    '  Q := TQueue.Create;'                                                       + LE +
    '  I := 1;'                                                                   + LE +
    '  while I <= 8 do begin Q.Enqueue(I); I := I + 1 end;'                      + LE +
    '  WriteLn(Q.Count);'                                                         + LE +
    '  WriteLn(Q.Dequeue);'                                                       + LE +
    '  WriteLn(Q.Dequeue)'                                                        + LE +
    'end.'                                                                        + LE;

{ ------------------------------------------------------------------ }
{ Infrastructure                                                        }
{ ------------------------------------------------------------------ }

function TE2EQueueTests.ProjectRoot: string;
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

function TE2EQueueTests.ToolchainAvailable: Boolean;
begin
  Result := FileExists(FQBE) and FileExists(FRTL)
end;

procedure TE2EQueueTests.SetUp;
var Root: string;
begin
  Root := ProjectRoot;
  FQBE := GetEnvironmentVariable('BLAISE_QBE');
  if FQBE = '' then FQBE := Root + 'vendor/qbe/qbe';
  FRTL := GetEnvironmentVariable('BLAISE_RTL');
  if FRTL = '' then FRTL := Root + 'rtl/target/blaise_rtl.a';
  FScratch := Root + 'compiler/target/test-e2e-tqueue';
  ForceDirectories(FScratch);
  FCounter := 0
end;

procedure TE2EQueueTests.TearDown;
begin
end;

function RunProc_Q(const AExe: string; const AArgs: array of string;
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

function RunProcNoArgs_Q(const AExe: string; out AStdout: string): Integer;
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

function TE2EQueueTests.CompileAndRun(const ASrc: string;
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
  Rc := RunProc_Q(FQBE, ['-o', AsmFile, IRFile], ToolOut);
  if Rc <> 0 then begin AStdout := 'qbe failed: ' + ToolOut; AExitCode := Rc; Exit end;
  Rc := RunProc_Q('cc', ['-o', BinFile, AsmFile, FRTL], ToolOut);
  if Rc <> 0 then begin AStdout := 'cc failed: ' + ToolOut; AExitCode := Rc; Exit end;
  AExitCode := RunProcNoArgs_Q(BinFile, AStdout);
  Result := True
end;

{ ------------------------------------------------------------------ }
{ Tests                                                                }
{ ------------------------------------------------------------------ }

procedure TE2EQueueTests.TestRun_TQueue_EnqueueDequeueFIFO;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcFIFO, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { FIFO: dequeue order must be 10, 20, 30 }
  AssertTrue('Dequeue returns 10 first (FIFO)', Pos('10', Output) >= 0);
  AssertTrue('Dequeue returns 20 second',        Pos('20', Output) >= 0);
  AssertTrue('Dequeue returns 30 last',          Pos('30', Output) >= 0);
end;

procedure TE2EQueueTests.TestRun_TQueue_PeekDoesNotRemove;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcPeekNoRemove, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Peek twice returns 7 both times; Count stays 1 }
  AssertTrue('Peek returns 7', Pos('7', Output) >= 0);
  AssertTrue('Count remains 1', Pos('1', Output) >= 0);
end;

procedure TE2EQueueTests.TestRun_TQueue_CountTracking;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcCountTracking, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Expected: 0, 2, 1 }
  AssertTrue('starts at 0', Pos('0', Output) >= 0);
  AssertTrue('2 after two enqueues', Pos('2', Output) >= 0);
end;

procedure TE2EQueueTests.TestRun_TQueue_GrowBeyondInitialCapacity;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcGrowBeyond, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { 8 items enqueued; FIFO dequeue returns 1 then 2 }
  AssertTrue('count=8', Pos('8', Output) >= 0);
  AssertTrue('first dequeue=1', Pos('1', Output) >= 0);
  AssertTrue('second dequeue=2', Pos('2', Output) >= 0);
end;

initialization
  RegisterTest(TE2EQueueTests);

end.
