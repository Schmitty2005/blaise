{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{
  blaise_mem — Pascal memory allocator for the Blaise runtime.

  Replaces libc malloc/free/realloc with a simple allocator backed by
  POSIX mmap/munmap.  Self-contained: no dependency on strings, ARC,
  or any stdlib unit.

  Design:

  Small allocations (up to LARGE_THRESHOLD bytes):
    Served from arenas (64 KB pages obtained via mmap).  Each allocation
    has an 8-byte header storing the usable size.  Freed blocks go onto
    a per-size-class freelist for O(1) reuse.  Size classes are powers
    of two from 16 to LARGE_THRESHOLD.

  Large allocations (above LARGE_THRESHOLD):
    Each gets its own mmap region with a 16-byte header (size + padding
    for alignment).  munmap releases the entire region.

  All returned pointers are 8-byte aligned (guaranteed by the 8-byte
  header on 8-byte-aligned arena blocks, and by mmap page alignment
  for large blocks).
}

unit blaise_mem;

{$mode objfpc}{$H+}

interface

function  _BlaiseGetMem(Size: Integer): Pointer;
procedure _BlaiseFreeMem(Ptr: Pointer);
function  _BlaiseReallocMem(Ptr: Pointer; NewSize: Integer): Pointer;

implementation

{ POSIX libc bindings — mmap/munmap for page-level allocation }
function  _libc_mmap(Addr: Pointer; Length: Int64; Prot, Flags, Fd: Integer;
            Offset: Int64): Pointer; external name 'mmap';
function  _libc_munmap(Addr: Pointer; Length: Int64): Integer;
            external name 'munmap';
procedure _libc_memcpy(Dst, Src: Pointer; N: Int64); external name 'memcpy';

const
  PROT_READ       = 1;
  PROT_WRITE      = 2;
  MAP_PRIVATE     = 2;
  MAP_ANONYMOUS   = 32;
  MAP_FAILED_VAL  = -1;

  ARENA_SIZE      = 65536;
  LARGE_THRESHOLD = 2048;
  HEADER_SIZE     = 8;
  LARGE_HEADER    = 16;
  NUM_SIZE_CLASSES = 8;
  MIN_CLASS_SIZE  = 16;

type
  PBlockHeader = ^TBlockHeader;
  TBlockHeader = record
    AllocSize: Integer;
    Flags:     Integer;
  end;

  PLargeHeader = ^TLargeHeader;
  TLargeHeader = record
    TotalMapped: Int64;
    AllocSize:   Int64;
  end;

  PFreeNode = ^TFreeNode;
  TFreeNode = record
    Next: PFreeNode;
  end;

  PArena = ^TArena;
  TArena = record
    Base:     Pointer;
    Offset:   Integer;
    Capacity: Integer;
    Next:     PArena;
  end;

const
  FLAG_LARGE = 1;
  FLAG_SMALL = 0;

var
  FreeLists: array[0..7] of PFreeNode;
  ArenaHead: PArena;

function MapFailed(P: Pointer): Boolean;
begin
  Result := (P = nil) or (PtrUInt(P) = PtrUInt(MAP_FAILED_VAL));
end;

function MmapAlloc(Size: Int64): Pointer;
begin
  Result := _libc_mmap(nil, Size,
    PROT_READ or PROT_WRITE,
    MAP_PRIVATE or MAP_ANONYMOUS,
    -1, 0);
  if MapFailed(Result) then
    Result := nil;
end;

function SizeClassIndex(Size: Integer): Integer;
var
  S: Integer;
begin
  S := MIN_CLASS_SIZE;
  Result := 0;
  while (S < Size) and (Result < NUM_SIZE_CLASSES - 1) do
  begin
    S := S * 2;
    Inc(Result);
  end;
end;

function SizeClassBytes(Index: Integer): Integer;
var
  S, I: Integer;
begin
  S := MIN_CLASS_SIZE;
  for I := 1 to Index do
    S := S * 2;
  Result := S;
end;

function RoundUpToClass(Size: Integer): Integer;
begin
  Result := SizeClassBytes(SizeClassIndex(Size));
end;

function AllocArena: PArena;
var
  Base: Pointer;
  A: PArena;
begin
  Base := MmapAlloc(Int64(ARENA_SIZE));
  if Base = nil then
  begin
    Result := nil;
    Exit;
  end;
  A := PArena(Base);
  A^.Base := Base;
  A^.Offset := SizeOf(TArena);
  A^.Capacity := ARENA_SIZE;
  A^.Next := ArenaHead;
  ArenaHead := A;
  Result := A;
end;

function AlignUp8(V: Integer): Integer;
begin
  Result := (V + 7) and $FFFFFFF8;
end;

function ArenaAlloc(Size: Integer): Pointer;
var
  A: PArena;
  BlockSize, Needed: Integer;
  Hdr: PBlockHeader;
begin
  BlockSize := RoundUpToClass(Size);
  Needed := HEADER_SIZE + BlockSize;

  A := ArenaHead;
  while A <> nil do
  begin
    if A^.Offset + Needed <= A^.Capacity then
    begin
      Hdr := Pointer(PtrUInt(A^.Base) + PtrUInt(A^.Offset));
      Hdr^.AllocSize := Size;
      Hdr^.Flags := FLAG_SMALL;
      A^.Offset := A^.Offset + Needed;
      Result := Pointer(PtrUInt(Hdr) + HEADER_SIZE);
      Exit;
    end;
    A := A^.Next;
  end;

  A := AllocArena;
  if A = nil then
  begin
    Result := nil;
    Exit;
  end;
  Hdr := Pointer(PtrUInt(A^.Base) + PtrUInt(A^.Offset));
  Hdr^.AllocSize := Size;
  Hdr^.Flags := FLAG_SMALL;
  A^.Offset := A^.Offset + Needed;
  Result := Pointer(PtrUInt(Hdr) + HEADER_SIZE);
end;

function SmallGetMem(Size: Integer): Pointer;
var
  Idx: Integer;
  Node: PFreeNode;
  Hdr: PBlockHeader;
begin
  Idx := SizeClassIndex(Size);

  Node := FreeLists[Idx];
  if Node <> nil then
  begin
    FreeLists[Idx] := Node^.Next;
    Hdr := PBlockHeader(Pointer(PtrUInt(Node) - HEADER_SIZE));
    Hdr^.AllocSize := Size;
    Result := Pointer(Node);
    Exit;
  end;

  Result := ArenaAlloc(Size);
end;

procedure SmallFreeMem(Ptr: Pointer);
var
  Hdr: PBlockHeader;
  Idx: Integer;
  ClassSize: Integer;
  Node: PFreeNode;
begin
  Hdr := PBlockHeader(Pointer(PtrUInt(Ptr) - HEADER_SIZE));
  ClassSize := RoundUpToClass(Hdr^.AllocSize);
  Idx := SizeClassIndex(ClassSize);
  Node := PFreeNode(Ptr);
  Node^.Next := FreeLists[Idx];
  FreeLists[Idx] := Node;
end;

function LargeGetMem(Size: Integer): Pointer;
var
  Total: Int64;
  Base: Pointer;
  Hdr: PLargeHeader;
begin
  Total := Int64(LARGE_HEADER) + Int64(Size);
  Base := MmapAlloc(Total);
  if Base = nil then
  begin
    Result := nil;
    Exit;
  end;
  Hdr := PLargeHeader(Base);
  Hdr^.TotalMapped := Total;
  Hdr^.AllocSize := Int64(Size);
  Result := Pointer(PtrUInt(Base) + LARGE_HEADER);
end;

procedure LargeFreeMem(Ptr: Pointer);
var
  Hdr: PLargeHeader;
begin
  Hdr := PLargeHeader(Pointer(PtrUInt(Ptr) - LARGE_HEADER));
  _libc_munmap(Pointer(Hdr), Hdr^.TotalMapped);
end;

function IsLarge(Ptr: Pointer): Boolean;
var
  Hdr: PBlockHeader;
begin
  Hdr := PBlockHeader(Pointer(PtrUInt(Ptr) - HEADER_SIZE));
  Result := Hdr^.Flags = FLAG_LARGE;
end;

function GetAllocSize(Ptr: Pointer): Integer;
var
  SmallHdr: PBlockHeader;
  LargeHdr: PLargeHeader;
begin
  SmallHdr := PBlockHeader(Pointer(PtrUInt(Ptr) - HEADER_SIZE));
  if SmallHdr^.Flags = FLAG_LARGE then
  begin
    LargeHdr := PLargeHeader(Pointer(PtrUInt(Ptr) - LARGE_HEADER));
    Result := Integer(LargeHdr^.AllocSize);
  end
  else
    Result := SmallHdr^.AllocSize;
end;

{ ------------------------------------------------------------------ }
{ Public API                                                           }
{ ------------------------------------------------------------------ }

function _BlaiseGetMem(Size: Integer): Pointer;
begin
  if Size <= 0 then
  begin
    Result := nil;
    Exit;
  end;
  if Size > LARGE_THRESHOLD then
    Result := LargeGetMem(Size)
  else
    Result := SmallGetMem(Size);
end;

procedure _BlaiseFreeMem(Ptr: Pointer);
begin
  if Ptr = nil then Exit;
  if IsLarge(Ptr) then
    LargeFreeMem(Ptr)
  else
    SmallFreeMem(Ptr);
end;

function _BlaiseReallocMem(Ptr: Pointer; NewSize: Integer): Pointer;
var
  OldSize, CopySize: Integer;
  Hdr: PBlockHeader;
begin
  if Ptr = nil then
  begin
    Result := _BlaiseGetMem(NewSize);
    Exit;
  end;
  if NewSize <= 0 then
  begin
    _BlaiseFreeMem(Ptr);
    Result := nil;
    Exit;
  end;
  OldSize := GetAllocSize(Ptr);
  if (not IsLarge(Ptr)) and (NewSize <= LARGE_THRESHOLD) then
  begin
    if RoundUpToClass(NewSize) = RoundUpToClass(OldSize) then
    begin
      Hdr := PBlockHeader(Pointer(PtrUInt(Ptr) - HEADER_SIZE));
      Hdr^.AllocSize := NewSize;
      Result := Ptr;
      Exit;
    end;
  end;
  Result := _BlaiseGetMem(NewSize);
  if Result = nil then Exit;
  if OldSize < NewSize then
    CopySize := OldSize
  else
    CopySize := NewSize;
  _libc_memcpy(Result, Ptr, Int64(CopySize));
  _BlaiseFreeMem(Ptr);
end;

initialization
  ArenaHead := nil;

end.
