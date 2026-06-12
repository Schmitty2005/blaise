{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit blaise.codegen.qbe.driver;

{ TBackendDriver subclass for the QBE backend.

  Owns the answers Blaise.pas used to compute via `if Backend = bkQBE`:
  which ICodeGen to instantiate (TCodeGenQBE) and its knob setup, the IR
  file extension (.ssa), and the qbe -> .s -> cc lowering/link steps.

  Architecture follows Andrew Haines' unify_backend_interface proposal.

  Pull this unit into Blaise.pas's uses clause; the initialization block
  registers the singleton driver. }

interface

uses
  blaise.codegen,
  blaise.codegen.qbe,
  blaise.codegen.driver;

type
  TQBEBackendDriver = class(TBackendDriver)
  public
    function Kind: TBackendKind; override;
    function Name: string; override;
    function IRFileExt: string; override;
    function SupportsIncremental: Boolean; override;
    function SupportsWarmCache: Boolean; override;
    function CreateCodeGen(AOpts: TBackendOpts): ICodeGen; override;
    function CreateUnitCodeGen(AOpts: TBackendOpts): ICodeGen; override;
  end;

implementation

function TQBEBackendDriver.Kind: TBackendKind;
begin
  Result := bkQBE;
end;

function TQBEBackendDriver.Name: string;
begin
  Result := 'qbe';
end;

function TQBEBackendDriver.IRFileExt: string;
begin
  Result := '.ssa';
end;

function TQBEBackendDriver.SupportsIncremental: Boolean;
begin
  Result := True;
end;

function TQBEBackendDriver.SupportsWarmCache: Boolean;
begin
  { QBE-emitted .o files participate in the warm cache: each parallel
    unit worker writes a .o + embedded .bif, uUnitLoader discovers them
    on the next compile and hash-matches against the .pas to decide
    whether to skip recompilation. }
  Result := True;
end;

function TQBEBackendDriver.CreateCodeGen(AOpts: TBackendOpts): ICodeGen;
var
  CG: TCodeGenQBE;
begin
  CG := TCodeGenQBE.Create();
  CG.SetDebugMode(AOpts.DebugMode);
  CG.SetOpdfMode(AOpts.OPDFEnabled);
  { TCodeGenQBE has no target knob; AOpts.Target only affects the
    link step. }
  Result := CG;
end;

function TQBEBackendDriver.CreateUnitCodeGen(AOpts: TBackendOpts): ICodeGen;
var
  CG: TCodeGenQBE;
begin
  { Same as CreateCodeGen plus SetExportAll(True) so sibling units in
    the link can resolve this unit's globals.  The knob is applied here
    so TCompileWorker relies on ICodeGen alone — no backend casts. }
  CG := TCodeGenQBE.Create();
  CG.SetDebugMode(AOpts.DebugMode);
  CG.SetOpdfMode(AOpts.OPDFEnabled);
  CG.SetExportAll(True);
  Result := CG;
end;

initialization
  RegisterDriver(TQBEBackendDriver.Create());

end.
