{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit runtime.syscall.linux;

// Linux x86_64 direct-syscall kernel leaf — the libc replacement for the thin
// 1:1 syscall wrappers (docs/linux-syscall-migration.adoc).
//
// This unit DEFINES the bare POSIX names (open, read, write, …) that
// rtl.platform.posix.pas references via `external name 'open'` etc.  When it is
// linked into a program (the --static link-time swap), those symbols resolve
// here as raw `syscall` stubs instead of being imported from libc.so.6 — so the
// resulting binary is a freestanding static ET_EXEC with no libc, no PT_INTERP.
//
// System V AMD64 -> Linux syscall ABI:
//   * syscall number in %rax; the `syscall` instruction returns in %rax.
//   * Argument registers DIFFER between the C ABI and the kernel ABI on the 4th
//     argument: C passes arg4 in %rcx, the kernel expects it in %r10 (the
//     `syscall` instruction itself clobbers %rcx).  Wrappers with >= 4 args
//     therefore `movq %rcx, %r10` first.  Args 1-3 (%rdi,%rsi,%rdx) and 5-6
//     (%r8,%r9) are already in the right registers.
//   * The kernel returns -errno on error (a small negative value).  libc would
//     translate that to a -1 return + `errno`; the existing Pascal call sites
//     test `if result < 0` / `if Fd < 0`, which a raw -errno also satisfies, so
//     no errno table is needed for these leaves.
//
// `nostackframe` lets each asm body own the frame so the registers hold the raw
// incoming arguments unmodified.

interface

{ File descriptors. }
function open(Path: PChar; Flags: Integer; Mode: Integer): Integer;
function close(Fd: Integer): Integer;
function read(Fd: Integer; Buf: Pointer; Count: Int64): Int64;
{ `write` collides with the Write/WriteLn builtin as a Pascal identifier, so the
  Pascal name is _sys_write; the asm body additionally emits a bare `write`
  label (.globl) so the linker symbol matches rtl.platform.posix's
  `external name 'write'`.  Every other leaf's name is a valid Pascal identifier
  and needs no alias. }
function _sys_write(Fd: Integer; Buf: Pointer; Count: Int64): Int64;
function lseek(Fd: Integer; Offset: Int64; Whence: Integer): Int64;

{ Filesystem. }
function fstat(Fd: Integer; Buf: Pointer): Integer;
function stat(Path: PChar; Buf: Pointer): Integer;
function mkdir(Path: PChar; Mode: Integer): Integer;
function rmdir(Path: PChar): Integer;
function unlink(Path: PChar): Integer;
function rename(OldPath, NewPath: PChar): Integer;
function chdir(Path: PChar): Integer;

{ Process. }
function getpid: Integer;
function dup2(OldFd, NewFd: Integer): Integer;
function pipe(Fds: Pointer): Integer;

{ Memory. }
function mmap(Addr: Pointer; Length: Int64; Prot, Flags, Fd: Integer;
             Offset: Int64): Pointer;
function munmap(Addr: Pointer; Length: Int64): Integer;

{ Time. }
function nanosleep(Req, Rem: Pointer): Integer;
function clock_gettime(ClockId: Integer; Ts: Pointer): Integer;

{ Process exit — exit_group(2), terminates all threads.  Neither runs atexit
  handlers (that lives in the atexit-registry leaf, a later step); for now the
  bare `exit` (called by main's epilogue) and `_exit` both terminate directly.
  `exit` is a reserved word in Pascal, so the Pascal proc is _sys_exit and the
  asm body emits a bare `exit` label (like `write` -> _sys_write). }
function _sys_exit(Code: Integer): Integer;
procedure _exit(Code: Integer);

implementation

{ ---- Linux x86_64 syscall numbers (arch/x86/entry/syscalls). ---- }
const
  SYS_read          = 0;
  SYS_write         = 1;
  SYS_open          = 2;
  SYS_close         = 3;
  SYS_stat          = 4;
  SYS_fstat         = 5;
  SYS_lseek         = 8;
  SYS_mmap          = 9;
  SYS_munmap        = 11;
  SYS_pipe          = 22;
  SYS_dup2          = 33;
  SYS_nanosleep     = 35;
  SYS_getpid        = 39;
  SYS_rename        = 82;
  SYS_mkdir         = 83;
  SYS_rmdir         = 84;
  SYS_unlink        = 87;
  SYS_chdir         = 80;
  SYS_clock_gettime = 228;
  SYS_exit_group    = 231;
{ The asm bodies use literal immediates (the assembler needs a literal, not a
  symbol); the const block above documents the number-to-name mapping. }

function open(Path: PChar; Flags: Integer; Mode: Integer): Integer;
  assembler; nostackframe;
asm
    movq $2, %rax        { SYS_open }
    syscall
    ret
end;

function close(Fd: Integer): Integer;
  assembler; nostackframe;
asm
    movq $3, %rax        { SYS_close }
    syscall
    ret
end;

function read(Fd: Integer; Buf: Pointer; Count: Int64): Int64;
  assembler; nostackframe;
asm
    movq $0, %rax        { SYS_read }
    syscall
    ret
end;

function _sys_write(Fd: Integer; Buf: Pointer; Count: Int64): Int64;
  assembler; nostackframe;
asm
.globl write
write:
    movq $1, %rax        { SYS_write }
    syscall
    ret
end;

function lseek(Fd: Integer; Offset: Int64; Whence: Integer): Int64;
  assembler; nostackframe;
asm
    movq $8, %rax        { SYS_lseek }
    syscall
    ret
end;

function fstat(Fd: Integer; Buf: Pointer): Integer;
  assembler; nostackframe;
asm
    movq $5, %rax        { SYS_fstat }
    syscall
    ret
end;

function stat(Path: PChar; Buf: Pointer): Integer;
  assembler; nostackframe;
asm
    movq $4, %rax        { SYS_stat }
    syscall
    ret
end;

function mkdir(Path: PChar; Mode: Integer): Integer;
  assembler; nostackframe;
asm
    movq $83, %rax       { SYS_mkdir }
    syscall
    ret
end;

function rmdir(Path: PChar): Integer;
  assembler; nostackframe;
asm
    movq $84, %rax       { SYS_rmdir }
    syscall
    ret
end;

function unlink(Path: PChar): Integer;
  assembler; nostackframe;
asm
    movq $87, %rax       { SYS_unlink }
    syscall
    ret
end;

function rename(OldPath, NewPath: PChar): Integer;
  assembler; nostackframe;
asm
    movq $82, %rax       { SYS_rename }
    syscall
    ret
end;

function chdir(Path: PChar): Integer;
  assembler; nostackframe;
asm
    movq $80, %rax       { SYS_chdir }
    syscall
    ret
end;

function getpid: Integer;
  assembler; nostackframe;
asm
    movq $39, %rax       { SYS_getpid }
    syscall
    ret
end;

function dup2(OldFd, NewFd: Integer): Integer;
  assembler; nostackframe;
asm
    movq $33, %rax       { SYS_dup2 }
    syscall
    ret
end;

function pipe(Fds: Pointer): Integer;
  assembler; nostackframe;
asm
    movq $22, %rax       { SYS_pipe }
    syscall
    ret
end;

{ mmap has 6 args; arg4 (Flags) arrives in %rcx (C ABI) but the kernel wants it
  in %r10.  Move it before the syscall. }
function mmap(Addr: Pointer; Length: Int64; Prot, Flags, Fd: Integer;
             Offset: Int64): Pointer;
  assembler; nostackframe;
asm
    movq %rcx, %r10
    movq $9, %rax        { SYS_mmap }
    syscall
    ret
end;

function munmap(Addr: Pointer; Length: Int64): Integer;
  assembler; nostackframe;
asm
    movq $11, %rax       { SYS_munmap }
    syscall
    ret
end;

function nanosleep(Req, Rem: Pointer): Integer;
  assembler; nostackframe;
asm
    movq $35, %rax       { SYS_nanosleep }
    syscall
    ret
end;

function clock_gettime(ClockId: Integer; Ts: Pointer): Integer;
  assembler; nostackframe;
asm
    movq $228, %rax      { SYS_clock_gettime }
    syscall
    ret
end;

{ exit_group(2) terminates the whole process (all threads) and does not return.
  The bare `exit` (called by main's epilogue) and `_exit` are the same raw
  terminator until the atexit-registry leaf lands.  Code arrives in %edi;
  exit_group reads its status from %rdi, so no marshalling is needed. }
function _sys_exit(Code: Integer): Integer;
  assembler; nostackframe;
asm
.globl exit
exit:
    movq $231, %rax      { SYS_exit_group }
    syscall
    ret
end;

procedure _exit(Code: Integer);
  assembler; nostackframe;
asm
    movq $231, %rax      { SYS_exit_group }
    syscall
    ret
end;

end.
