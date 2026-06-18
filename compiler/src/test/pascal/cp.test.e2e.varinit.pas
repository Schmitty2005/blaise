{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.e2e.varinit;

{ E2E tests for initialised global variables (var G: T = value): compile ->
  run, asserting stdout on every backend (QBE + native).  The IR-level tests
  live in cp.test.varinit.pas. }

interface

uses
  classes, blaise.testing, cp.test.e2e.base;

type
  [Threaded]
  TE2EVarInitTests = class(TE2ETestCase)
  protected
    procedure SetUp; override;
  published
    procedure TestRun_IntegerInit;
    procedure TestRun_StringInit;
    procedure TestRun_BooleanInit;
    procedure TestRun_RealInit;
    procedure TestRun_Int64Init;
    procedure TestRun_ArrayInit_ZeroBased;
    procedure TestRun_ArrayInit_NonZeroBased;
    procedure TestRun_MultipleInits;
    procedure TestRun_InitThenReassign;
    procedure TestRun_FloatConstFold_Parens;
    procedure TestRun_FloatConstFold_NegativeMul;
  end;

implementation

procedure TE2EVarInitTests.SetUp;
begin
  inherited SetUp();
  SetUpScratch('compiler/target/test-e2e-varinit')
end;

procedure TE2EVarInitTests.TestRun_IntegerInit;
const Src =
  '''
  program P;
  var G: Integer = 42;
  begin
    WriteLn(G)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, '42' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_StringInit;
const Src =
  '''
  program P;
  var S: string = 'hello world';
  begin
    WriteLn(S)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, 'hello world' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_BooleanInit;
const Src =
  '''
  program P;
  var B: Boolean = True;
  begin
    if B then WriteLn('yes') else WriteLn('no')
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, 'yes' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_RealInit;
const Src =
  '''
  program P;
  var D: Double = 3.5;
  begin
    WriteLn(D)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, '3.5' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_Int64Init;
const Src =
  '''
  program P;
  var Big: Int64 = 9999999999;
  begin
    WriteLn(Big)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, '9999999999' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_ArrayInit_ZeroBased;
const Src =
  '''
  program P;
  var A: array[0..2] of Integer = (10, 20, 30);
  begin
    WriteLn(A[0]); WriteLn(A[1]); WriteLn(A[2])
  end.
  ''';
var LE: string;
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  LE := LineEnding;
  AssertRunsOnAll(Src, '10' + LE + '20' + LE + '30' + LE, 0);
end;

procedure TE2EVarInitTests.TestRun_ArrayInit_NonZeroBased;
const Src =
  '''
  program P;
  var R: array[1..3] of Integer = (7, 8, 9);
  begin
    WriteLn(R[1]); WriteLn(R[3])
  end.
  ''';
var LE: string;
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  LE := LineEnding;
  AssertRunsOnAll(Src, '7' + LE + '9' + LE, 0);
end;

procedure TE2EVarInitTests.TestRun_MultipleInits;
const Src =
  '''
  program P;
  var
    A: Integer = 1;
    B: Integer = 2;
    C: string = 'three';
  begin
    WriteLn(A); WriteLn(B); WriteLn(C)
  end.
  ''';
var LE: string;
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  LE := LineEnding;
  AssertRunsOnAll(Src, '1' + LE + '2' + LE + 'three' + LE, 0);
end;

procedure TE2EVarInitTests.TestRun_InitThenReassign;
const Src =
  '''
  program P;
  var G: Integer = 10;
  begin
    WriteLn(G);
    G := G + 5;
    WriteLn(G)
  end.
  ''';
var LE: string;
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  LE := LineEnding;
  AssertRunsOnAll(Src, '10' + LE + '15' + LE, 0);
end;

{ Compile-time float-const folding crosses the codegen->run boundary here: the
  compiler folds the expression (uSemantic.RawDoubleToStr) and bakes the literal
  into the IR, then the running program prints it.  An IR-only test cannot catch
  a folding bug that depends on the host ABI — the compiler's own RawDoubleToStr
  once called libc snprintf through a fixed-arg declaration, which violates the
  SysV variadic ABI (%al unset) and mis-folded on some hosts.  These run-and-
  compare tests pin the actual folded value on every backend. }
procedure TE2EVarInitTests.TestRun_FloatConstFold_Parens;
const Src =
  '''
  program P;
  const X = (1.0 + 2.0) * 3.0;
  begin
    WriteLn(X)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, '9' + LineEnding, 0);
end;

procedure TE2EVarInitTests.TestRun_FloatConstFold_NegativeMul;
const Src =
  '''
  program P;
  const X = -1.5 * 2.0;
  begin
    WriteLn(X)
  end.
  ''';
begin
  if not ToolchainAvailable() then begin Ignore('toolchain unavailable'); Exit end;
  AssertRunsOnAll(Src, '-3' + LineEnding, 0);
end;

initialization
  RegisterTest(TE2EVarInitTests);

end.
