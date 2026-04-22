unit Generics.Collections;

// Blaise RTL — generic collections (mirrors Delphi's System.Generics.Collections
// and FPC's Generics.Collections for source-level compatibility).
//
// NOTE: This file is compiled by the Blaise compiler, not FPC.

interface

type
  TList<T> = class
    FData:     ^T;
    FCount:    Integer;
    FCapacity: Integer;
    procedure Grow;
    procedure Add(Value: T);
    function  Get(AIndex: Integer): T;
    procedure Delete(AIndex: Integer);
    procedure Clear;
    procedure Free;
    property Count: Integer read FCount;
  end;

implementation

procedure TList<T>.Grow;
var
  NewCap: Integer;
begin
  if Self.FCapacity = 0 then
    NewCap := 4
  else
    NewCap := Self.FCapacity * 2;
  Self.FData     := ReallocMem(Self.FData, NewCap * SizeOf(T));
  Self.FCapacity := NewCap
end;

procedure TList<T>.Add(Value: T);
var
  Dest: ^T;
begin
  if Self.FCount = Self.FCapacity then
    Self.Grow;
  Dest        := Self.FData + Self.FCount * SizeOf(T);
  Dest^       := Value;
  Self.FCount := Self.FCount + 1
end;

function TList<T>.Get(AIndex: Integer): T;
var
  Src: ^T;
begin
  Src    := Self.FData + AIndex * SizeOf(T);
  Result := Src^
end;

procedure TList<T>.Delete(AIndex: Integer);
var
  Src: ^T;
  Dst: ^T;
  I:   Integer;
begin
  I := AIndex;
  while I < Self.FCount - 1 do
  begin
    Dst  := Self.FData + I * SizeOf(T);
    Src  := Self.FData + (I + 1) * SizeOf(T);
    Dst^ := Src^;
    I    := I + 1
  end;
  Self.FCount := Self.FCount - 1
end;

procedure TList<T>.Clear;
begin
  Self.FCount := 0
end;

procedure TList<T>.Free;
begin
  FreeMem(Self.FData)
end;

end.
