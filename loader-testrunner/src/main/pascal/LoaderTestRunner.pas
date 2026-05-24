{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Andrew Haines
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{ Loader / TUnitInterface test runner.

  Lives outside compiler/TestRunner.pas deliberately:
    * Exercises the unit-loader and unit-interface seam — a new
      architectural surface (Phase 1 of the separate-compilation work),
      not part of the compiler's existing functional surface.
    * Keeps churn off the main TestRunner.pas while the loader/interface
      contract is being shaped — avoids merge pain against upstream master.
    * Lets the loader work proceed on the fixes_loader branch with its
      own test gate; once the design stabilises, individual cases can
      migrate into compiler/src/test/pascal/. }

program LoaderTestRunner;

uses
  blaise.testing,
  blaise.testing.runner.text,
  cp.test.unitinterface;

begin
  Halt(RunAll);
end.
