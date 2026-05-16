{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{ punit tests for blaise_mem — the Pascal memory allocator.

  These tests exercise the allocator at the raw pointer level, below
  the string and ARC subsystems.  punit is the correct framework here
  because blaise_mem has zero dependency on stdlib or ARC.

  Build:
    blaise --source runtime/src/test/pascal/test_blaise_mem.pas \
           --unit-path runtime/src/main/pascal \
           --unit-path runtime/src/test/pascal \
           --emit-ir > /tmp/test_mem.ssa
    vendor/qbe/qbe -o /tmp/test_mem.s /tmp/test_mem.ssa
    gcc -o /tmp/test_mem /tmp/test_mem.s compiler/target/blaise_rtl.a
    /tmp/test_mem -v
}

program test_blaise_mem;

uses
  punit, blaise_mem;

{ ------------------------------------------------------------------ }
{ Test: basic GetMem returns non-nil                                   }
{ ------------------------------------------------------------------ }
function Test_GetMem_Basic: string;
var
  P: Pointer;
begin
  P := _BlaiseGetMem(64);
  AssertNotNull('GetMem(64) returns non-nil', P);
  _BlaiseFreeMem(P);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: GetMem(0) returns nil                                          }
{ ------------------------------------------------------------------ }
function Test_GetMem_Zero: string;
var
  P: Pointer;
begin
  P := _BlaiseGetMem(0);
  AssertNull('GetMem(0) returns nil', P);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: allocated memory is writable and readable                      }
{ ------------------------------------------------------------------ }
function Test_ReadWrite: string;
var
  P: PChar;
begin
  P := PChar(_BlaiseGetMem(16));
  AssertNotNull('alloc for read/write', Pointer(P));
  P[0] := 65;
  P[1] := 66;
  P[2] := 67;
  P[3] := 0;
  AssertEquals('written byte 0', 65, Integer(P[0]));
  AssertEquals('written byte 1', 66, Integer(P[1]));
  AssertEquals('written byte 2', 67, Integer(P[2]));
  _BlaiseFreeMem(Pointer(P));
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: multiple allocations return distinct pointers                  }
{ ------------------------------------------------------------------ }
function Test_Distinct_Pointers: string;
var
  A, B, C: Pointer;
begin
  A := _BlaiseGetMem(32);
  B := _BlaiseGetMem(32);
  C := _BlaiseGetMem(32);
  AssertNotNull('A non-nil', A);
  AssertNotNull('B non-nil', B);
  AssertNotNull('C non-nil', C);
  AssertDiffers('A <> B', A, B);
  AssertDiffers('A <> C', A, C);
  AssertDiffers('B <> C', B, C);
  _BlaiseFreeMem(C);
  _BlaiseFreeMem(B);
  _BlaiseFreeMem(A);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: FreeMem(nil) is safe (no-op)                                   }
{ ------------------------------------------------------------------ }
function Test_FreeMem_Nil: string;
begin
  _BlaiseFreeMem(nil);
  AssertPassed;
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: ReallocMem grows allocation                                    }
{ ------------------------------------------------------------------ }
function Test_ReallocMem_Grow: string;
var
  P: PChar;
begin
  P := PChar(_BlaiseGetMem(8));
  AssertNotNull('initial alloc', Pointer(P));
  P[0] := 72;
  P[1] := 73;
  P := PChar(_BlaiseReallocMem(Pointer(P), 64));
  AssertNotNull('realloc result', Pointer(P));
  AssertEquals('byte 0 preserved', 72, Integer(P[0]));
  AssertEquals('byte 1 preserved', 73, Integer(P[1]));
  _BlaiseFreeMem(Pointer(P));
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: ReallocMem(nil, N) acts like GetMem                            }
{ ------------------------------------------------------------------ }
function Test_ReallocMem_FromNil: string;
var
  P: Pointer;
begin
  P := _BlaiseReallocMem(nil, 32);
  AssertNotNull('realloc from nil', P);
  _BlaiseFreeMem(P);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: ReallocMem(P, 0) acts like FreeMem                             }
{ ------------------------------------------------------------------ }
function Test_ReallocMem_ToZero: string;
var
  P: Pointer;
begin
  P := _BlaiseGetMem(32);
  AssertNotNull('initial alloc', P);
  P := _BlaiseReallocMem(P, 0);
  AssertNull('realloc to 0 returns nil', P);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: small allocation (8 bytes) — exercises small-block path        }
{ ------------------------------------------------------------------ }
function Test_Small_Alloc: string;
var
  P: PChar;
begin
  P := PChar(_BlaiseGetMem(8));
  AssertNotNull('small alloc', Pointer(P));
  P[0] := 42;
  AssertEquals('small alloc writable', 42, Integer(P[0]));
  _BlaiseFreeMem(Pointer(P));
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: large allocation (1 MB) — exercises mmap direct path           }
{ ------------------------------------------------------------------ }
function Test_Large_Alloc: string;
var
  P: PChar;
  Size: Integer;
begin
  Size := 1024 * 1024;
  P := PChar(_BlaiseGetMem(Size));
  AssertNotNull('large alloc', Pointer(P));
  P[0] := 1;
  P[Size - 1] := 2;
  AssertEquals('large alloc first byte', 1, Integer(P[0]));
  AssertEquals('large alloc last byte', 2, Integer(P[Size - 1]));
  _BlaiseFreeMem(Pointer(P));
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: alloc-free-alloc reuse (freelist)                               }
{ ------------------------------------------------------------------ }
function Test_Reuse_After_Free: string;
var
  A, B: Pointer;
begin
  A := _BlaiseGetMem(64);
  _BlaiseFreeMem(A);
  B := _BlaiseGetMem(64);
  AssertNotNull('reuse alloc', B);
  _BlaiseFreeMem(B);
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: many small allocations (stress test)                            }
{ ------------------------------------------------------------------ }
function Test_Many_Small_Allocs: string;
const
  Count = 1000;
var
  I: Integer;
  P: Pointer;
begin
  for I := 0 to Count - 1 do
  begin
    P := _BlaiseGetMem(24);
    AssertNotNull('alloc ' + IntToStr(I), P);
    _BlaiseFreeMem(P);
  end;
  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: various size classes                                            }
{ ------------------------------------------------------------------ }
function Test_Size_Classes: string;
var
  P: Pointer;
begin
  P := _BlaiseGetMem(1);
  AssertNotNull('1 byte', P);
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(16);
  AssertNotNull('16 bytes', P);
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(128);
  AssertNotNull('128 bytes', P);
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(1024);
  AssertNotNull('1024 bytes', P);
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(4096);
  AssertNotNull('4096 bytes', P);
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(65536);
  AssertNotNull('65536 bytes', P);
  _BlaiseFreeMem(P);

  Result := '';
end;

{ ------------------------------------------------------------------ }
{ Test: alignment — returned pointer is 8-byte aligned                 }
{ ------------------------------------------------------------------ }
function Test_Alignment: string;
var
  P: Pointer;
  Addr: PtrUInt;
begin
  P := _BlaiseGetMem(7);
  AssertNotNull('alloc for alignment test', P);
  Addr := PtrUInt(P);
  AssertEquals('8-byte aligned', 0, Integer(Addr and 7));
  _BlaiseFreeMem(P);

  P := _BlaiseGetMem(1);
  AssertNotNull('alloc for alignment test (1 byte)', P);
  Addr := PtrUInt(P);
  AssertEquals('8-byte aligned (1 byte)', 0, Integer(Addr and 7));
  _BlaiseFreeMem(P);

  Result := '';
end;

begin
  AddSuite('blaise_mem', nil);
  AddTest('GetMem_Basic',         @Test_GetMem_Basic,         'blaise_mem');
  AddTest('GetMem_Zero',          @Test_GetMem_Zero,          'blaise_mem');
  AddTest('ReadWrite',            @Test_ReadWrite,            'blaise_mem');
  AddTest('Distinct_Pointers',    @Test_Distinct_Pointers,    'blaise_mem');
  AddTest('FreeMem_Nil',          @Test_FreeMem_Nil,          'blaise_mem');
  AddTest('ReallocMem_Grow',      @Test_ReallocMem_Grow,      'blaise_mem');
  AddTest('ReallocMem_FromNil',   @Test_ReallocMem_FromNil,   'blaise_mem');
  AddTest('ReallocMem_ToZero',    @Test_ReallocMem_ToZero,    'blaise_mem');
  AddTest('Small_Alloc',          @Test_Small_Alloc,          'blaise_mem');
  AddTest('Large_Alloc',          @Test_Large_Alloc,          'blaise_mem');
  AddTest('Reuse_After_Free',     @Test_Reuse_After_Free,     'blaise_mem');
  AddTest('Many_Small_Allocs',    @Test_Many_Small_Allocs,    'blaise_mem');
  AddTest('Size_Classes',         @Test_Size_Classes,         'blaise_mem');
  AddTest('Alignment',            @Test_Alignment,            'blaise_mem');
  RunAllSysTests;
end.
