{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit runtime.start.static.linux;

// Freestanding `_start` for a static, libc-free Linux ET_EXEC (the --static
// kernel-leaf swap; docs/linux-syscall-migration.adoc).
//
// The libc-backed runtime.start calls __libc_start_main, which only exists when
// linking libc.  This variant is the drop-in replacement linked instead when a
// program is built --static: it sets up argc/argv from the raw process stack and
// jumps straight to `main` (which the backend emits to call _SetArgs/_BlaiseInit,
// run the body, and `exit`).
//
// On entry the kernel hands us the initial process stack (System V AMD64,
// "Initial Process Stack"):
//   (%rsp)      = argc
//   8(%rsp)     = argv[0], argv[1], … then a NULL, then envp, then auxv.
// %rsp is 16-byte aligned at the kernel's `_start` only AFTER we account for the
// implicit return address a normal `call` would have pushed — i.e. on entry
// (%rsp) points at argc and the ABI's "16-byte aligned at call site" means after
// our own alignment the stack is correct for the `call main`.
//
// main expects C-`main(argc, argv)` register layout: argc in %edi, argv in %rsi.

interface

procedure _start;

implementation

procedure _start; assembler; nostackframe;
asm
    endbr64
    xor  %ebp, %ebp            { clear frame pointer — outermost frame }
    movq (%rsp), %rdi          { %rdi = argc }
    leaq 8(%rsp), %rsi         { %rsi = &argv[0] }
    andq $0xfffffffffffffff0, %rsp   { 16-byte align before the call }
    call main
    xorl %edi, %edi           { main terminates via exit; guard with exit_group(0) }
    movq $231, %rax           { SYS_exit_group }
    syscall
    hlt
end;

end.
