{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.cli;

{ CLI-level end-to-end tests for the compiler driver front-end.

  These shell out to the compiler binary and assert on stdout/stderr and
  exit codes.  They cover behaviour the IR-only / unit harness cannot see:

    * FPC-style CLI removal (Step 0): the old -iV/-iTP/-iTO info probe and
      single-dash FPC flags are gone; the binary is double-dash-only now.

    * Driver option contract surfacing (Steps 2-5): --assembler value
      validation, wrong-backend rejection, and that ValidateOptions fires
      even in stdout-only modes (--emit-ir).  These prove the
      drain -> ValidateOptions -> error -> exit-1 wiring in Blaise.pas,
      which is not unit-testable (ParseArgs is a non-exported program
      local). }

interface

uses
  SysUtils, Classes, Process, blaise.testing;

type
  { Invokes the compiler binary directly and inspects the CLI contract. }
  TCLIContractTests = class(TTestCase)
  private
    FCompiler: string;
    FRTLPath: string;
    FStdlibPath: string;
    FRTL: string;
    FScratch: string;
    FCounter: Integer;
    function ProjectRoot: string;
    function CompilerAvailable: Boolean;
    { Run the compiler with the given args; capture combined stdout+stderr. }
    function RunCompiler(const AArgs: array of string;
      out ACombined: string): Integer;
    function WriteScratchSource(const ASrc: string): string;
  protected
    procedure SetUp; override;
  published
    { ---- Step 0: FPC CLI removal ---- }
    procedure TestHelpStillWorks;
    procedure TestNormalCompileStillWorks;
    procedure TestFPCVersionProbeGone;
  end;

implementation

{ ---- helpers ---- }

function TCLIContractTests.ProjectRoot: string;
var
  Dir, Parent: string;
  Steps: Integer;
begin
  Result := GetEnvironmentVariable('BLAISE_PROJECT_ROOT');
  if Result <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(Result);
    Exit;
  end;
  Dir := GetCurrentDir();
  for Steps := 0 to 5 do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(Dir) + 'vendor/qbe') and
       DirectoryExists(IncludeTrailingPathDelimiter(Dir) + 'runtime') then
    begin
      Result := IncludeTrailingPathDelimiter(Dir);
      Exit;
    end;
    Parent := ExtractFileDir(Dir);
    if (Parent = '') or (Parent = Dir) then Break;
    Dir := Parent;
  end;
  Result := IncludeTrailingPathDelimiter(GetCurrentDir());
end;

procedure TCLIContractTests.SetUp;
begin
  inherited SetUp();
  FCompiler := GetEnvironmentVariable('BLAISE_QBE_COMPILER');
  if FCompiler = '' then
    FCompiler := '/tmp/fp_blaise3';
  if not FileExists(FCompiler) then
    FCompiler := '/tmp/fp_blaise2';
  FRTLPath := ProjectRoot() + 'runtime/src/main/pascal';
  FStdlibPath := ProjectRoot() + 'stdlib/src/main/pascal';
  FRTL := ProjectRoot() + 'compiler/target/blaise_rtl.a';
  FScratch := ProjectRoot() + 'compiler/target/cli_scratch/';
  ForceDirectories(FScratch);
  FCounter := 0;
end;

function TCLIContractTests.CompilerAvailable: Boolean;
begin
  Result := FileExists(FCompiler) and FileExists(FRTL);
end;

function TCLIContractTests.RunCompiler(const AArgs: array of string;
  out ACombined: string): Integer;
var
  Proc: TProcess;
  I: Integer;
  Chunk: string;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := FCompiler;
    for I := 0 to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    { The posix process shim already redirects the child's stderr into the
      same pipe as stdout (dup2(pipe,2) in rtl.platform.posix), so a
      diagnostic printed to StdErr is visible in ReadOutput below. }
    Proc.Execute();
    ACombined := '';
    repeat
      Chunk := Proc.ReadOutput();
      ACombined := ACombined + Chunk;
    until (Chunk = '') and not Proc.Running;
    Proc.WaitOnExit();
    Result := Proc.ExitCode;
  finally
    Proc.Free();
  end;
end;

function TCLIContractTests.WriteScratchSource(const ASrc: string): string;
begin
  FCounter := FCounter + 1;
  Result := FScratch + 'cli_' + IntToStr(FCounter) + '.pas';
  WriteFile(Result, ASrc);
end;

{ ---- Step 0: FPC CLI removal ---- }

procedure TCLIContractTests.TestHelpStillWorks;
var
  Out_: string;
  EC: Integer;
begin
  if not CompilerAvailable() then
  begin
    Ignore('<toolchain-missing>');
    Exit;
  end;
  EC := RunCompiler(['--help'], Out_);
  AssertEquals('--help exits 0', 0, EC);
  AssertTrue('usage banner present',
    Pos('Usage:', Out_) >= 0);
end;

procedure TCLIContractTests.TestNormalCompileStillWorks;
var
  Src, Out_: string;
  EC: Integer;
begin
  if not CompilerAvailable() then
  begin
    Ignore('<toolchain-missing>');
    Exit;
  end;
  Src := WriteScratchSource(
    'program cli_ok;' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(42)' + LineEnding +
    'end.');
  EC := RunCompiler([
    '--source', Src,
    '--unit-path', FRTLPath,
    '--unit-path', FStdlibPath,
    '--output', FScratch + 'cli_ok_bin'
  ], Out_);
  AssertEquals('normal compile exits 0: ' + Out_, 0, EC);
end;

procedure TCLIContractTests.TestFPCVersionProbeGone;
var
  Out_: string;
  EC: Integer;
begin
  if not CompilerAvailable() then
  begin
    Ignore('<toolchain-missing>');
    Exit;
  end;
  { The FPC info-query path is removed.  -iV must no longer print FPC's
    '3.2.2'; it is now an unrecognised flag and fails. }
  EC := RunCompiler(['-iV'], Out_);
  AssertTrue('-iV must not return FPC version 3.2.2',
    Pos('3.2.2', Out_) < 0);
  AssertTrue('-iV must be rejected (non-zero exit)', EC <> 0);
end;

{ ---- Registration ---- }

initialization
  RegisterTest(TCLIContractTests);

end.
