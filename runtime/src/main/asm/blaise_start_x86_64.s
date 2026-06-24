#
# Blaise — An Object Pascal Compiler
# Copyright (c) 2026 Graeme Geldenhuys
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
# Licensed under the Apache License v2.0 with Runtime Library Exception.
# See LICENSE file in the project root for full license terms.
#
# Program entry point (x86_64, System V ABI, glibc-compatible).
#
# This replaces the system Scrt1.o so the internal linker needs no
# gcc-provided startup object and no versioned gcc directory (issue #142).
# The runtime ships its own _start; the linker (TLinker.Link '_start') uses
# this symbol as the ELF entry point.
#
# On entry the kernel hands us the initial process stack:
#   (%rsp)      argc
#   8(%rsp)     argv[0]
#   ...         argv[argc] = NULL, then envp, then the auxiliary vector
# and %rdx holds the dynamic linker's finaliser (rtld_fini) for PIE images.
#
# We marshal these into the arguments __libc_start_main expects:
#   __libc_start_main(main, argc, argv, init, fini, rtld_fini, stack_end)
#     %rdi = main          (the program's C-style entry)
#     %rsi = argc
#     %rdx = argv
#     %rcx = init   = NULL  (unit init runs from main, not .init_array)
#     %r8  = fini   = NULL
#     %r9  = rtld_fini
#     stack_end pushed on the stack
# glibc runs the init array (if any), calls main(argc, argv, envp), then
# exit(main's return value).  This mirrors modern glibc's own Scrt1.o.

.text

.globl _start
.type  _start, @function
_start:
    endbr64
    xor  %ebp, %ebp                 # outermost frame marker (ABI)
    mov  %rdx, %r9                  # rtld_fini -> arg 7
    pop  %rsi                       # argc -> arg 2
    mov  %rsp, %rdx                 # argv -> arg 3 (now at stack top)
    and  $0xfffffffffffffff0, %rsp  # re-align stack to 16 bytes
    push %rax                       # padding (8 bytes) ...
    push %rsp                       # ... and stack_end, keeping alignment
    xor  %r8d, %r8d                 # fini = NULL  -> arg 5
    xor  %ecx, %ecx                 # init = NULL  -> arg 4
    lea  main(%rip), %rdi           # main -> arg 1
    call __libc_start_main@PLT      # does not return
    hlt                             # trap if it ever does
.size _start, .-_start

.section .note.GNU-stack,"",@progbits
