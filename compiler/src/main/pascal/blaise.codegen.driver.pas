{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit blaise.codegen.driver;

{ Cross-backend driver abstraction.

  Each backend registers a TBackendDriver subclass singleton.  Blaise.pas
  and TCompileWorker drive the shared pipeline through the base class and
  stop branching on the backend kind for per-backend tool invocation,
  file extensions, and codegen construction.

  Responsibilities a driver OWNS:

    * Codegen construction: which ICodeGen to create and how to apply its
      backend-specific knobs (e.g. the native backend's SetTarget).

    * IR-text artefact shape: the file extension used for the emitted IR,
      so the shared pipeline can pick the right file name without a
      backend switch.

    * Lowering and linking: turning the emitted IR file into a
      relocatable object (per-unit incremental path) or the final linked
      binary (program path).  The QBE driver runs qbe + cc; the native
      driver runs cc on its assembly directly, or the in-process
      assembler + linker driver when --assembler internal is selected.

  Responsibilities a driver does NOT own:

    * Warm-cache discovery, source-hash validation, prebuilt-object
      probing.  Those stay in uUnitLoader and are backend-agnostic.
      SupportsWarmCache exists only as a hint for future "this backend's
      .o isn't trusted for cache reuse yet" gating.

    * .bif embedding into unit objects — an object-format concern shared
      across backends; it stays with the caller (Blaise.pas).

  The architecture follows Andrew Haines' unify_backend_interface
  proposal, with a class-based dispatch surface (virtual methods on an
  abstract base) instead of an interface so shared behaviour — toolchain
  resolution, the common link line — lives in the base class.

  Lifetime: driver singletons are registered once at unit initialization
  into a fixed array of class references.  They are ARC-managed globals,
  released by the program-exit global release pass (the codebase norm for
  unit-level singletons — no explicit finalization needed). }

interface

uses
  Classes,
  blaise.codegen,
  blaise.codegen.target,
  uToolchain;

type
  TBackendKind = (bkQBE, bkNative);

  { Result of offering an unrecognised flag to a driver (Chain of
    Responsibility). }
  TOptionAccept = (
    oaUnknown,        { not my flag — keep trying / report unknown }
    oaConsumedFlag,   { mine, took no value argument }
    oaConsumedValue   { mine, consumed the following arg as its value }
  );

  { Cross-cutting flags that affect codegen, lowering, and linking.
    Built once by the Blaise.pas flag parser and shared (read-only) with
    the compile workers.  Adding a new backend knob is a field here plus
    the driver that reads it; Blaise.pas does not branch on backend to
    apply it. }
  TBackendOpts = class
  public
    Target: TTargetDesc;
    DebugMode: Boolean;       { codegen debug / leak tracking }
    OPDFEnabled: Boolean;     { OPDF code shaping }
    OPDFAsmFile: string;      { OPDF sidecar path, if any }
    UseInternalAsm: Boolean;  { --assembler internal (native backend) }
    AssemblerExplicit: Boolean;  { True when user passed --assembler }
    AssemblerChoiceBad: Boolean;  { a --assembler value was given that is
                                neither 'internal' nor 'external'; the
                                native driver's ValidateOptions rejects it }
    UseInternalLinker: Boolean;  { --linker internal (native backend) }
    LinkerExplicit: Boolean;     { True when user passed --linker }
    LinkerChoiceBad: Boolean;    { --linker value not 'internal' or 'external' }
    RTLSrcDir: string;           { --rtl-src DIR: explicit RTL source directory.
                                   Overrides the binary/CWD-relative lookup, for
                                   a relocated/release binary whose RTL source
                                   lives elsewhere (empty = use default lookup) }
  end;

  TBackendDriver = class
  public
    { Static description of the backend. }
    function Kind: TBackendKind; virtual; abstract;
    function Name: string; virtual; abstract;       { '--backend' identifier }
    function IRFileExt: string; virtual; abstract;  { '.ssa' | '.s' }

    { True when the driver can emit a per-unit linkable artefact for the
      --incremental worker pool.  A driver returning True here MUST
      return a non-nil codegen from CreateUnitCodeGen — the worker fails
      loudly otherwise. }
    function SupportsIncremental: Boolean; virtual;

    { True when uUnitLoader may reuse this backend's .o + .bif on a
      content-hash match.  QBE = true today; native = false until it
      learns to write .bif sidecars and the loader trusts them. }
    function SupportsWarmCache: Boolean; virtual;

    { The external tools this backend needs for ATarget, as resolvable
      specs.  uToolchain.ResolveSpec turns each into a path (env override,
      $BLAISE_TOOLCHAIN_PREFIX, cross-triple prefix, $PATH, host ext).  The
      base lists the shared linker (cc, or the mingw cross-linker for a
      Windows target); a backend overrides to add its own (e.g. the LLVM
      driver appends llc) — call inherited and extend. }
    function DescribeTools(const ATarget: TTargetDesc): TToolSpecArray; virtual;

    { Resolve one named tool from DescribeTools for ATarget; '' if the
      backend declares no such tool. }
    function ToolPath(const AName: string; const ATarget: TTargetDesc): string;

    { Verify any tools the backend needs are reachable.  Returns '' on
      success, an error message otherwise.  Called once before the
      front-end runs (skipped for stdout-only modes, which need no
      toolchain). }
    function CheckToolchain(AOpts: TBackendOpts): string; virtual;

    { Construct the backend's code generator and apply opts.  Returns an
      ARC-managed ICodeGen — do not Free. }
    function CreateCodeGen(AOpts: TBackendOpts): ICodeGen; virtual; abstract;

    { Per-unit codegen for the parallel incremental worker, configured to
      emit a single unit's IR with exports visible to sibling units.
      Default nil: the driver does not support separate-unit emission and
      the dispatcher falls back to the QBE driver. }
    function CreateUnitCodeGen(AOpts: TBackendOpts): ICodeGen; virtual;

    { Lower one unit's IR file to a relocatable object (--incremental
      worker path and unit-as-top-level mode).  Returns '' on success,
      an error message otherwise.  Default fails loudly: a driver that
      claims SupportsIncremental must override this. }
    function LowerToObject(const AIRFile, AObjFile: string;
      AOpts: TBackendOpts): string; virtual;

    { Lower the top program's IR file and link the final binary —
      including the OPDF sidecar, prebuilt dep objects, the RTL archive,
      and -lm/-lpthread.  Returns '' on success, an error message
      otherwise.  AExtraObjects may be nil. }
    function LinkProgram(const AIRFile, AOutputFile: string;
      AOpts: TBackendOpts; AExtraObjects: TStringList): string; virtual; abstract;

    { --- Option contract (Chain of Responsibility + Template Method) --- }

    { The common parser, on a flag it does not own, offers it here.  The
      driver writes any parsed state into the shared AOpts (the same
      TBackendOpts the drivers later read).  Returns oaConsumedValue when
      it took ANextArg as the flag's value, oaConsumedFlag when the flag
      stood alone, oaUnknown when the flag is not this driver's.  Default
      oaUnknown. }
    function AcceptOption(const AFlag, ANextArg: string;
      AOpts: TBackendOpts): TOptionAccept; virtual;

    { Contribute this backend's flag lines to --help.  One (flag,
      description) pair per AddOptionLine call; FormatFlagLine owns the
      column layout so driver lines never drift from the shared block.
      Default: nothing. }
    procedure DescribeOptions(ALines: TStringList); virtual;

    { Post-parse validation with the resolved TBackendOpts visible.
      Returns '' when valid, else a user-facing message.  THIS is where
      cross-cutting rules live ("OPDF debug info is not supported by the
      LLVM backend").  Default ''. }
    function ValidateOptions(AOpts: TBackendOpts): string; virtual;

    { Selection policy: does this backend produce the IR text that
      --emit-ir prints?  QBE = True (fixpoint / RTL-Makefile contract on
      byte-identical QBE IR); native = False (its IR IS assembly, surfaced
      via --emit-asm).  PickTopDriver asks this instead of hard-coding
      bkQBE.  Default False. }
    function ClaimsEmitIR: Boolean; virtual;

  protected
    { The shared linker tool spec for ATarget (cc/clang, or the mingw
      cross-linker for a Windows target).  A subclass's DescribeTools builds
      its array from this plus its own tools — the parser has no
      expression-position `inherited`, so this is the reuse seam. }
    function LinkerToolSpec(const ATarget: TTargetDesc): TToolSpec;

    { Shared link line: cc-driver resolved via uToolchain (env overrides
      and target awareness apply), input file, OPDF sidecar, extra
      objects, the RTL objects, -lm, -lpthread.  Used by every driver's
      LinkProgram. }
    function LinkViaToolchain(const AInputFile, AOutputFile: string;
      AOpts: TBackendOpts; AExtraObjects: TStringList): string;

    { Compile the implicit RTL units (runtime.* + rtl.platform.*) from source
      into a per-compiler object cache and return their .o paths in AObjPaths
      (link order).  A unit is (re)compiled only when its cached .o is missing
      or older than the source.  Replaces the pre-built blaise_rtl.a — the RTL
      is built from source by the compiler itself (docs/rtl-unification-plan.adoc).
      Both the cc link line and the native internal linker call this.

      RTL units carry inline asm, so they are always built with the native
      backend + internal assembler.  Building goes through a --unit-cache so a
      unit that uses another RTL unit references its globals externally instead
      of re-defining them — without that, the per-unit objects clash on
      duplicate global definitions when linked directly (the archive's member
      selection used to hide this).  The cache also auto-builds intermediate
      deps (e.g. rtl.platform), which are collected too.

      AIncludeStartup controls whether runtime.start.o (which defines the bare
      `_start` entry) is included.  The native internal linker needs it (Blaise
      owns the entry point); the cc/QBE link line must omit it (libc's startup
      provides `_start` and calls `main`), or the two `_start`s collide.

      Returns '' on success, else an error message. }
    function EnsureRTLObjects(AOpts: TBackendOpts; AIncludeStartup: Boolean;
      AObjPaths: TStringList): string;
  end;

{ Run an external tool, capturing combined output.  Shared by the
  drivers; exposed because the lowering steps run from worker threads
  as well as the main compile path. }
function RunProcess(const AExe: string; AArgs: TStringList;
  out AOutput: string): Integer;

{ Format one --help flag line with the shared 2-space indent and flag
  column.  Single source of truth for the column width so the common
  usage block (Blaise.pas PrintUsage) and each driver's DescribeOptions
  cannot drift.  Example:
    FormatFlagLine('--assembler <id>', 'internal | external (default: external)')
  produces '  --assembler <id>    internal | external (default: external)'. }
function FormatFlagLine(const AFlag, ADesc: string): string;

{ Registry.  Each backend unit registers its singleton in its
  initialization block; consumers fetch by kind.  Looking up an
  unregistered kind raises an exception (programmer error — the backend
  unit wasn't pulled into the uses clause). }

procedure RegisterDriver(ADriver: TBackendDriver);
function GetDriver(AKind: TBackendKind): TBackendDriver;

{ Enumerate registered backends in TBackendKind ordinal order.  Returns a
  TStringList of Name values; caller owns and frees.  Drives --backend
  validation and the usage printer so neither hard-codes the list. }
function RegisteredBackendNames: TStringList;

{ Parse a --backend identifier against the registered drivers.  Returns
  False on an unknown name; caller writes the user-facing error. }
function ParseBackendName(const AName: string; out AKind: TBackendKind): Boolean;

{ The single backend-selection policy decision.  --emit-ir always forces
  QBE (the fixpoint check + RTL Makefile depend on byte-identical QBE
  IR); --emit-asm implies native (its IR IS the .s text the consumer
  expects); otherwise --backend selects directly. }
function PickTopDriver(ABackend: TBackendKind;
  AEmitIR, AEmitAsm: Boolean): TBackendDriver;

implementation

uses
  SysUtils,
  Process,
  uToolchain;

{ Indexed by Ord(TBackendKind).  The bound is a literal because the
  parser only accepts integer literals on array decls; keep the upper
  bound in sync with the enum's highest ordinal (bkNative = 1). }
var
  GDrivers: array[0..1] of TBackendDriver;

function TBackendDriver.SupportsIncremental: Boolean;
begin
  Result := False;
end;

function TBackendDriver.SupportsWarmCache: Boolean;
begin
  Result := False;
end;

function TBackendDriver.LinkerToolSpec(const ATarget: TTargetDesc): TToolSpec;
begin
  { Shared linker slot.  A target tool (HostTool=False): native build uses
    cc/clang; a Windows target cross-links via the mingw clang driver
    (x86_64-w64-mingw32-clang) and never falls back to the host cc. }
  Result.Name     := 'linker';
  Result.EnvVar   := 'BLAISE_LINKER';
  SetLength(Result.Cands, 2);
  Result.Cands[0] := 'cc';
  Result.Cands[1] := 'clang';
  Result.HostTool := False;
  if ATarget.OS = osWindows then
    Result.CrossPrefix := 'x86_64-w64-mingw32-'
  else
    Result.CrossPrefix := '';
end;

function TBackendDriver.DescribeTools(const ATarget: TTargetDesc): TToolSpecArray;
begin
  SetLength(Result, 1);
  Result[0] := Self.LinkerToolSpec(ATarget);
end;

function TBackendDriver.ToolPath(const AName: string;
  const ATarget: TTargetDesc): string;
var
  Specs: TToolSpecArray;
  I:     Integer;
begin
  Result := '';
  Specs := Self.DescribeTools(ATarget);
  for I := 0 to High(Specs) do
    if SameText(Specs[I].Name, AName) then
      Exit(ResolveSpec(Specs[I], ATarget));
end;

function TBackendDriver.CheckToolchain(AOpts: TBackendOpts): string;
begin
  { No tools to probe by default.  AOpts is part of the signature so a
    backend probe can read e.g. AOpts.Target. }
  Result := '';
end;

function TBackendDriver.AcceptOption(const AFlag, ANextArg: string;
  AOpts: TBackendOpts): TOptionAccept;
begin
  Result := oaUnknown;
end;

procedure TBackendDriver.DescribeOptions(ALines: TStringList);
begin
  { No backend-private flags by default. }
end;

function TBackendDriver.ValidateOptions(AOpts: TBackendOpts): string;
begin
  Result := '';
end;

function TBackendDriver.ClaimsEmitIR: Boolean;
begin
  Result := False;
end;

function TBackendDriver.CreateUnitCodeGen(AOpts: TBackendOpts): ICodeGen;
begin
  Result := nil;
end;

function TBackendDriver.LowerToObject(const AIRFile, AObjFile: string;
  AOpts: TBackendOpts): string;
begin
  Result := Self.Name() +
    ' backend does not support per-unit object lowering';
end;

{ The implicit RTL units, in dependency/link order (leaf-first).  The compiler
  emits calls to their symbols (_SetArgs, _BlaiseGetMem, _start, ARC helpers, …)
  in every program, so every program links them.  Names are the dotted-flat
  unit names; the source files are <name>.pas in the RTL source directory.
  rtl.platform is the base abstraction layout.linux + posix both use; it owns
  the shared globals (GPlatformLayout, GRtlPlatform) so it must be built first
  and linked once. }
const
  RTL_UNITS: array[0..14] of string = (
    'rtl.platform',
    'runtime.start', 'runtime.atomic', 'runtime.setjmp', 'runtime.utf8',
    'runtime.mem', 'runtime.str', 'runtime.set', 'runtime.arc',
    'runtime.weak', 'runtime.float', 'runtime.thread', 'runtime.exc',
    'rtl.platform.layout.linux', 'rtl.platform.posix');

function TBackendDriver.EnsureRTLObjects(AOpts: TBackendOpts;
  AIncludeStartup: Boolean; AObjPaths: TStringList): string;
var
  SrcDir, CacheDir, BlaiseBin: string;
  SrcFile, ObjFile: string;
  I, ExitCode: Integer;
  Args: TStringList;
  Msg: string;
begin
  Result := '';
  { RTL source lives in the compiler's own source tree.  Resolution order:
      1. --rtl-src DIR (AOpts.RTLSrcDir) — explicit, for a relocated binary;
      2. $BLAISE_RTL_SRC;
      3. binary/CWD-relative default (RTLSourceDir). }
  if AOpts.RTLSrcDir <> '' then
    SrcDir := ExpandFileName(AOpts.RTLSrcDir)
  else
  begin
    SrcDir := GetEnvironmentVariable('BLAISE_RTL_SRC');
    if SrcDir = '' then
      SrcDir := ExpandFileName(RTLSourceDir());
  end;
  if not DirectoryExists(SrcDir) then
    Exit('RTL source directory not found (' + SrcDir +
      '); pass --rtl-src DIR or set $BLAISE_RTL_SRC to compiler/src/main/pascal');

  { Object cache lives beside the compiler binary so repeated program builds
    reuse it (compiler/target/rtl/). }
  CacheDir := IncludeTrailingPathDelimiter(CompilerBinDir()) + 'rtl';
  ForceDirectories(CacheDir);
  BlaiseBin := ParamStr(0);

  for I := 0 to High(RTL_UNITS) do
  begin
    SrcFile := IncludeTrailingPathDelimiter(SrcDir) + RTL_UNITS[I] + '.pas';
    ObjFile := IncludeTrailingPathDelimiter(CacheDir) + RTL_UNITS[I] + '.o';
    if not FileExists(SrcFile) then
      Exit('RTL unit source missing: ' + SrcFile);

    { Recompile only when the cached object is missing or stale.  The build
      goes through --unit-cache so each unit's RTL deps are referenced
      externally (no duplicate global definitions); building leaf-first means
      a unit's deps are already cached when it compiles.  RTL units carry
      inline asm, so the native backend + internal assembler is mandatory. }
    if (not FileExists(ObjFile)) or (FileAge(ObjFile) < FileAge(SrcFile)) then
    begin
      Args := TStringList.Create();
      try
        Args.Add('--backend');     Args.Add('native');
        Args.Add('--assembler');   Args.Add('internal');
        Args.Add('--source');      Args.Add(SrcFile);
        Args.Add('--unit-path');   Args.Add(SrcDir);
        Args.Add('--unit-cache');  Args.Add(CacheDir);
        Args.Add('--output');      Args.Add(ObjFile);
        ExitCode := RunProcess(BlaiseBin, Args, Msg);
      finally
        Args.Free();
      end;
      if ExitCode <> 0 then
        Exit('failed to build RTL unit ' + RTL_UNITS[I] +
          ' (exit ' + IntToStr(ExitCode) + '): ' + Msg);
    end;

    { runtime.start defines the bare _start entry — include it only for the
      native internal linker (Blaise owns the entry); the cc link line gets
      _start from libc and must omit it to avoid a multiple-definition. }
    if SameText(RTL_UNITS[I], 'runtime.start') and (not AIncludeStartup) then
      Continue;
    AObjPaths.Add(ObjFile);
  end;
end;

function TBackendDriver.LinkViaToolchain(const AInputFile, AOutputFile: string;
  AOpts: TBackendOpts; AExtraObjects: TStringList): string;
var
  Args: TStringList;
  RTLObjs: TStringList;
  Msg, RTLErr: string;
  ExitCode: Integer;
  I: Integer;
begin
  Result := '';
  { Every Blaise program links the implicit RTL units (runtime.* +
    rtl.platform.*).  They are no longer shipped as a pre-built blaise_rtl.a;
    the compiler builds them from source into a per-compiler object cache
    (EnsureRTLObjects) and links the resulting .o files directly.  This is the
    same RTL the native internal linker uses — one source of truth. }
  Args := TStringList.Create();
  RTLObjs := TStringList.Create();
  try
    { cc link line: libc supplies _start, so omit runtime.start. }
    RTLErr := Self.EnsureRTLObjects(AOpts, False, RTLObjs);
    if RTLErr <> '' then
      Exit(RTLErr);
    Args.Add('-o');
    Args.Add(AOutputFile);
    Args.Add(AInputFile);
    { Linker resolved via DescribeTools so a Windows target picks the mingw
      cross-linker and a Windows host adds the .exe extension. }
    { OPDF sidecar (QBE backend only — the native backend appends its
      exact-facts OPDF section to the main assembly instead). }
    if (AOpts.OPDFAsmFile <> '') and FileExists(AOpts.OPDFAsmFile) then
      Args.Add(AOpts.OPDFAsmFile);
    { Pre-built dep object files (auto-discovered by the loader or
      produced by the --incremental workers). }
    if AExtraObjects <> nil then
      for I := 0 to AExtraObjects.Count - 1 do
        Args.Add(AExtraObjects.Strings[I]);
    { RTL objects, in link order. }
    for I := 0 to RTLObjs.Count - 1 do
      Args.Add(RTLObjs.Strings[I]);
    Args.Add('-lm');       { math functions (sqrt, sin, cos, etc.) }
    Args.Add('-lpthread'); { POSIX threads (blaise_thread unit) }
    ExitCode := RunProcess(Self.ToolPath('linker', AOpts.Target), Args, Msg);
  finally
    RTLObjs.Free();
    Args.Free();
  end;
  if ExitCode <> 0 then
    Result := 'link error (exit ' + IntToStr(ExitCode) + '): ' + Msg;
end;

function FormatFlagLine(const AFlag, ADesc: string): string;
const
  { Matches the shared usage block in Blaise.pas PrintUsage: 2-space
    indent, flag field padded so the description starts at column 20. }
  Indent = '  ';
  FlagFieldWidth = 18;
var
  Pad: Integer;
begin
  Result := Indent + AFlag;
  Pad := FlagFieldWidth - Length(AFlag);
  if Pad < 1 then
    Pad := 1;   { always at least one space before the description }
  while Pad > 0 do
  begin
    Result := Result + ' ';
    Pad := Pad - 1;
  end;
  Result := Result + ADesc;
end;

function ReadProcessChunk(AProc: TProcess): string;
begin
  Result := AProc.ReadOutput()
end;

function RunProcess(const AExe: string; AArgs: TStringList;
  out AOutput: string): Integer;
var
  Proc: TProcess;
  Chunk: string;
  I: Integer;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExe;
    for I := 0 to AArgs.Count - 1 do
      Proc.Parameters.Add(AArgs.Strings[I]);
    Proc.Execute();
    AOutput := '';
    repeat
      Chunk := ReadProcessChunk(Proc);
      AOutput := AOutput + Chunk;
    until (Chunk = '') and not Proc.Running;
    Proc.WaitOnExit();
    Result := Proc.ExitCode;
  finally
    Proc.Free();
  end;
end;

procedure RegisterDriver(ADriver: TBackendDriver);
begin
  GDrivers[Ord(ADriver.Kind())] := ADriver;
end;

function GetDriver(AKind: TBackendKind): TBackendDriver;
begin
  Result := GDrivers[Ord(AKind)];
  if Result = nil then
    raise Exception.Create(
      'blaise.codegen.driver: no driver registered for backend kind ' +
      IntToStr(Ord(AKind)) + ' (unit not pulled into uses clause?)');
end;

function RegisteredBackendNames: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create();
  for I := 0 to 1 do
    if GDrivers[I] <> nil then
      Result.Add(GDrivers[I].Name());
end;

function ParseBackendName(const AName: string; out AKind: TBackendKind): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to 1 do
    if (GDrivers[I] <> nil) and SameText(AName, GDrivers[I].Name()) then
    begin
      AKind := GDrivers[I].Kind();
      Result := True;
      Exit;
    end;
end;

function PickTopDriver(ABackend: TBackendKind;
  AEmitIR, AEmitAsm: Boolean): TBackendDriver;
var
  I: Integer;
begin
  if AEmitIR then
  begin
    { --emit-ir prints the IR text of whichever backend claims it.  Ask
      the drivers instead of hard-coding bkQBE, so a future IR-producing
      backend (LLVM) needs no carve-out here. }
    for I := 0 to 1 do
      if (GDrivers[I] <> nil) and GDrivers[I].ClaimsEmitIR() then
        Exit(GDrivers[I]);
    { No registered backend claims --emit-ir: fall back to QBE, the
      historical owner of the byte-identical IR contract. }
    Result := GetDriver(bkQBE);
  end
  else if AEmitAsm then
    Result := GetDriver(bkNative)
  else
    Result := GetDriver(ABackend);
end;

end.
