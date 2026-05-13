{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.imap;

{ E2E tests for IMap<K,V>: compile -> QBE -> cc -> run, assert on stdout.
  Verifies that interface dispatch through IMap<K,V> routes to the correct
  concrete implementation at runtime — both TDictionary and TOrderedDictionary. }

interface

uses
  classes, sysutils, process, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TE2EIMapTests = class(TTestCase)
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
    procedure TestRun_IMap_TDictionary_AddAndContainsKey;
    procedure TestRun_IMap_TDictionary_TryGetValue;
    procedure TestRun_IMap_TDictionary_Remove;
    procedure TestRun_IMap_TOrderedDictionary_AddAndContainsKey;
    procedure TestRun_IMap_TOrderedDictionary_TryGetValue;
    procedure TestRun_IMap_SwapImplementation_SameCallSite;
  end;

implementation

const
  { Shared IMap interface declaration used in all test programs }
  IMapSrc =
    '''
    program P;
    type
      IMap = interface
        procedure Add(Key, Value: Integer);
        function  TryGetValue(Key: Integer; var Value: Integer): Boolean;
        function  ContainsKey(Key: Integer): Boolean;
        procedure Remove(Key: Integer);
        function  GetCount: Integer;
      end;
    ''';

  { Non-generic TDict implementing IMap (concrete Integer key/value for E2E) }
  TDictSrc =
    '''
      TDict = class(IMap)
        FKeys:     ^Integer;
        FValues:   ^Integer;
        FCount:    Integer;
        FCapacity: Integer;
        procedure Grow;
        var NewCap, OldCap: Integer;
        begin
          OldCap := Self.FCapacity;
          if OldCap = 0 then NewCap := 8 else NewCap := OldCap * 2;
          Self.FKeys   := ReallocMem(Self.FKeys,   NewCap * SizeOf(Integer));
          ZeroMem(Self.FKeys + OldCap * SizeOf(Integer), (NewCap-OldCap) * SizeOf(Integer));
          Self.FValues := ReallocMem(Self.FValues, NewCap * SizeOf(Integer));
          ZeroMem(Self.FValues + OldCap * SizeOf(Integer), (NewCap-OldCap) * SizeOf(Integer));
          Self.FCapacity := NewCap
        end;
        function FindKey(Key: Integer): Integer;
        var I: Integer; Ptr: ^Integer;
        begin
          Result := -1; I := 0;
          while I < Self.FCount do begin
            Ptr := Self.FKeys + I * SizeOf(Integer);
            if Ptr^ = Key then begin Result := I; break end;
            I := I + 1
          end
        end;
        procedure Add(Key, Value: Integer);
        var Idx: Integer; KPtr, VPtr: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            VPtr := Self.FValues + Idx * SizeOf(Integer); VPtr^ := Value
          end else begin
            if Self.FCount = Self.FCapacity then Self.Grow;
            KPtr := Self.FKeys   + Self.FCount * SizeOf(Integer);
            VPtr := Self.FValues + Self.FCount * SizeOf(Integer);
            KPtr^ := Key; VPtr^ := Value;
            Self.FCount := Self.FCount + 1
          end
        end;
        function TryGetValue(Key: Integer; var Value: Integer): Boolean;
        var Idx: Integer; VPtr: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            VPtr := Self.FValues + Idx * SizeOf(Integer);
            Value := VPtr^; Result := True
          end else Result := False
        end;
        function ContainsKey(Key: Integer): Boolean;
        begin Result := Self.FindKey(Key) >= 0 end;
        procedure Remove(Key: Integer);
        var Idx, I: Integer; KDst, KSrc, VDst, VSrc: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            I := Idx;
            while I < Self.FCount - 1 do begin
              KDst := Self.FKeys   + I * SizeOf(Integer);
              KSrc := Self.FKeys   + (I+1) * SizeOf(Integer);
              VDst := Self.FValues + I * SizeOf(Integer);
              VSrc := Self.FValues + (I+1) * SizeOf(Integer);
              KDst^ := KSrc^; VDst^ := VSrc^; I := I + 1
            end;
            Self.FCount := Self.FCount - 1
          end
        end;
        function GetCount: Integer;
        begin Result := Self.FCount end;
        property Count: Integer read GetCount;
      end;
    ''';

  { Insertion-ordered variant implementing the same IMap interface }
  TOrdDictSrc =
    '''
      TOrdDict = class(IMap)
        FKeys:     ^Integer;
        FValues:   ^Integer;
        FCount:    Integer;
        FCapacity: Integer;
        procedure Grow;
        var NewCap, OldCap: Integer;
        begin
          OldCap := Self.FCapacity;
          if OldCap = 0 then NewCap := 8 else NewCap := OldCap * 2;
          Self.FKeys   := ReallocMem(Self.FKeys,   NewCap * SizeOf(Integer));
          ZeroMem(Self.FKeys + OldCap * SizeOf(Integer), (NewCap-OldCap) * SizeOf(Integer));
          Self.FValues := ReallocMem(Self.FValues, NewCap * SizeOf(Integer));
          ZeroMem(Self.FValues + OldCap * SizeOf(Integer), (NewCap-OldCap) * SizeOf(Integer));
          Self.FCapacity := NewCap
        end;
        function FindKey(Key: Integer): Integer;
        var I: Integer; Ptr: ^Integer;
        begin
          Result := -1; I := 0;
          while I < Self.FCount do begin
            Ptr := Self.FKeys + I * SizeOf(Integer);
            if Ptr^ = Key then begin Result := I; break end;
            I := I + 1
          end
        end;
        procedure Add(Key, Value: Integer);
        var Idx: Integer; KPtr, VPtr: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            VPtr := Self.FValues + Idx * SizeOf(Integer); VPtr^ := Value
          end else begin
            if Self.FCount = Self.FCapacity then Self.Grow;
            KPtr := Self.FKeys   + Self.FCount * SizeOf(Integer);
            VPtr := Self.FValues + Self.FCount * SizeOf(Integer);
            KPtr^ := Key; VPtr^ := Value;
            Self.FCount := Self.FCount + 1
          end
        end;
        function TryGetValue(Key: Integer; var Value: Integer): Boolean;
        var Idx: Integer; VPtr: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            VPtr := Self.FValues + Idx * SizeOf(Integer);
            Value := VPtr^; Result := True
          end else Result := False
        end;
        function ContainsKey(Key: Integer): Boolean;
        begin Result := Self.FindKey(Key) >= 0 end;
        procedure Remove(Key: Integer);
        var Idx, I: Integer; KDst, KSrc, VDst, VSrc: ^Integer;
        begin
          Idx := Self.FindKey(Key);
          if Idx >= 0 then begin
            I := Idx;
            while I < Self.FCount - 1 do begin
              KDst := Self.FKeys   + I * SizeOf(Integer);
              KSrc := Self.FKeys   + (I+1) * SizeOf(Integer);
              VDst := Self.FValues + I * SizeOf(Integer);
              VSrc := Self.FValues + (I+1) * SizeOf(Integer);
              KDst^ := KSrc^; VDst^ := VSrc^; I := I + 1
            end;
            Self.FCount := Self.FCount - 1
          end
        end;
        function GetCount: Integer;
        begin Result := Self.FCount end;
        property Count: Integer read GetCount;
      end;
    ''';

  { Add via IMap, ContainsKey via IMap, print result }
  SrcDictAddContains =
    IMapSrc +
    '''
    type
    ''' +
    TDictSrc +
    '''
    var M: IMap;
    begin
      M := TDict.Create;
      M.Add(10, 100);
      M.Add(20, 200);
      WriteLn(M.ContainsKey(10));
      WriteLn(M.ContainsKey(99));
      WriteLn(M.GetCount)
    end.
    ''';

  { TryGetValue via IMap }
  SrcDictTryGet =
    IMapSrc +
    '''
    type
    ''' +
    TDictSrc +
    '''
    var M: IMap; V: Integer; OK: Boolean;
    begin
      M := TDict.Create;
      M.Add(42, 99);
      OK := M.TryGetValue(42, V);
      WriteLn(OK);
      WriteLn(V);
      OK := M.TryGetValue(7, V);
      WriteLn(OK)
    end.
    ''';

  { Remove via IMap }
  SrcDictRemove =
    IMapSrc +
    '''
    type
    ''' +
    TDictSrc +
    '''
    var M: IMap;
    begin
      M := TDict.Create;
      M.Add(1, 10); M.Add(2, 20); M.Add(3, 30);
      M.Remove(2);
      WriteLn(M.GetCount);
      WriteLn(M.ContainsKey(2));
      WriteLn(M.ContainsKey(1))
    end.
    ''';

  { Same operations through TOrdDict implementing the same IMap }
  SrcOrdDictAddContains =
    IMapSrc +
    '''
    type
    ''' +
    TOrdDictSrc +
    '''
    var M: IMap;
    begin
      M := TOrdDict.Create;
      M.Add(10, 100);
      M.Add(20, 200);
      WriteLn(M.ContainsKey(10));
      WriteLn(M.ContainsKey(99));
      WriteLn(M.GetCount)
    end.
    ''';

  { TryGetValue via TOrdDict/IMap }
  SrcOrdDictTryGet =
    IMapSrc +
    '''
    type
    ''' +
    TOrdDictSrc +
    '''
    var M: IMap; V: Integer; OK: Boolean;
    begin
      M := TOrdDict.Create;
      M.Add(42, 99);
      OK := M.TryGetValue(42, V);
      WriteLn(OK);
      WriteLn(V);
      OK := M.TryGetValue(7, V);
      WriteLn(OK)
    end.
    ''';

  { Swap implementation: same call site, two different concrete types }
  SrcSwapImpl =
    IMapSrc +
    '''
    type
    ''' +
    TDictSrc +
    TOrdDictSrc +
    '''
    var M: IMap; Flag: Boolean;
    begin
      M := TDict.Create;
      M.Add(5, 50);
      Flag := M.ContainsKey(5);
      WriteLn(Flag);
      M := TOrdDict.Create;
      M.Add(5, 50);
      Flag := M.ContainsKey(5);
      WriteLn(Flag)
    end.
    ''';

{ ------------------------------------------------------------------ }
{ Infrastructure                                                        }
{ ------------------------------------------------------------------ }

function TE2EIMapTests.ProjectRoot: string;
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

function TE2EIMapTests.ToolchainAvailable: Boolean;
begin
  Result := FileExists(FQBE) and FileExists(FRTL)
end;

procedure TE2EIMapTests.SetUp;
var Root: string;
begin
  Root := ProjectRoot;
  FQBE := GetEnvironmentVariable('BLAISE_QBE');
  if FQBE = '' then FQBE := Root + 'vendor/qbe/qbe';
  FRTL := GetEnvironmentVariable('BLAISE_RTL');
  if FRTL = '' then FRTL := Root + 'rtl/target/blaise_rtl.a';
  FScratch := Root + 'compiler/target/test-e2e-imap';
  ForceDirectories(FScratch);
  FCounter := 0
end;

procedure TE2EIMapTests.TearDown;
begin
end;

function RunProc_IM(const AExe: string; const AArgs: array of string;
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

function RunProcNoArgs_IM(const AExe: string; out AStdout: string): Integer;
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

function TE2EIMapTests.CompileAndRun(const ASrc: string;
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
  Rc := RunProc_IM(FQBE, ['-o', AsmFile, IRFile], ToolOut);
  if Rc <> 0 then begin AStdout := 'qbe failed: ' + ToolOut; AExitCode := Rc; Exit end;
  Rc := RunProc_IM('cc', ['-o', BinFile, AsmFile, FRTL], ToolOut);
  if Rc <> 0 then begin AStdout := 'cc failed: ' + ToolOut; AExitCode := Rc; Exit end;
  AExitCode := RunProcNoArgs_IM(BinFile, AStdout);
  Result := True
end;

{ ------------------------------------------------------------------ }
{ Tests                                                                }
{ ------------------------------------------------------------------ }

procedure TE2EIMapTests.TestRun_IMap_TDictionary_AddAndContainsKey;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcDictAddContains, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { ContainsKey(10) -> true (1), ContainsKey(99) -> false (0), Count=2 }
  AssertTrue('contains 10 -> 1', Pos('1', Output) >= 0);
  AssertTrue('contains 99 -> 0', Pos('0', Output) >= 0);
  AssertTrue('count=2',          Pos('2', Output) >= 0);
end;

procedure TE2EIMapTests.TestRun_IMap_TDictionary_TryGetValue;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcDictTryGet, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { TryGetValue(42)->true(1), value=99, TryGetValue(7)->false(0) }
  AssertTrue('found -> 1',  Pos('1',  Output) >= 0);
  AssertTrue('value=99',    Pos('99', Output) >= 0);
  AssertTrue('missing -> 0', Pos('0', Output) >= 0);
end;

procedure TE2EIMapTests.TestRun_IMap_TDictionary_Remove;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcDictRemove, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Count=2, ContainsKey(2)->false(0), ContainsKey(1)->true(1) }
  AssertTrue('count=2',         Pos('2', Output) >= 0);
  AssertTrue('removed key gone', Pos('0', Output) >= 0);
  AssertTrue('other key stays', Pos('1', Output) >= 0);
end;

procedure TE2EIMapTests.TestRun_IMap_TOrderedDictionary_AddAndContainsKey;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcOrdDictAddContains, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Same expected output as TDict — dispatch routes to TOrdDict at runtime }
  AssertTrue('contains 10 -> 1', Pos('1', Output) >= 0);
  AssertTrue('contains 99 -> 0', Pos('0', Output) >= 0);
  AssertTrue('count=2',          Pos('2', Output) >= 0);
end;

procedure TE2EIMapTests.TestRun_IMap_TOrderedDictionary_TryGetValue;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcOrdDictTryGet, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  AssertTrue('found -> 1',   Pos('1',  Output) >= 0);
  AssertTrue('value=99',     Pos('99', Output) >= 0);
  AssertTrue('missing -> 0', Pos('0',  Output) >= 0);
end;

procedure TE2EIMapTests.TestRun_IMap_SwapImplementation_SameCallSite;
var
  Output: string;
  RCode:  Integer;
begin
  if not ToolchainAvailable then begin Fail('<toolchain-missing>'); Exit end;
  AssertTrue('compile+run', CompileAndRun(SrcSwapImpl, Output, RCode));
  AssertEquals('exit 0', 0, RCode);
  { Both ContainsKey calls return true (1) — one via TDict, one via TOrdDict }
  AssertTrue('TDict dispatch correct',    Pos('1', Output) >= 0);
  AssertTrue('TOrdDict dispatch correct', Pos('1', Output) >= 0);
end;

initialization
  RegisterTest(TE2EIMapTests);

end.
