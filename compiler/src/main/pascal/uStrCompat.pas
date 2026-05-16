{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{
  String helpers — 0-based string conventions.

  Blaise strings are 0-based: S[0] is the first character, Pos returns
  a 0-based index (-1 = not found), Copy takes a 0-based From argument.

  Usage:
    - Replace s[1] with StrAt(s, 0)
    - Replace Pos(sub, s) > 0  with Pos(sub, s) >= 0
    - Replace Copy(s, n, len)  with Copy(s, n, len)  (already 0-based in Blaise)
    - Use StrAt(s, i) instead of s[i+1] style char access
}

unit uStrCompat;

interface

{ StrAt: return ordinal of character at 0-based index I }
function StrAt(const S: string; I: Integer): Integer;

{ StrCopyFrom: copy from 0-based position From, Count chars }
function StrCopyFrom(const S: string; From, Count: Integer): string;

{ StrCopyTail: copy from 0-based position From to end of string }
function StrCopyTail(const S: string; From: Integer): string;

{ StrHead: copy the first N characters (equivalent to Copy(s, 0, N)) }
function StrHead(const S: string; N: Integer): string;

{ StrPos: find sub in s, return 0-based index; -1 if not found }
function StrPos(const Sub, S: string): Integer;

{ StripUnderscores: return S with all '_' characters removed }
function StripUnderscores(const S: string): string;

{ ParseIntLiteral: convert a Pascal integer-literal token value to Int64.
  Accepts decimal, $hex, %binary, &octal, with optional _ separators.
  Raises EConvertError on invalid input. }
function ParseIntLiteral(const S: string): Int64;

implementation

function StrAt(const S: string; I: Integer): Integer;
begin
  Result := OrdAt(S, I);
end;

function StrCopyFrom(const S: string; From, Count: Integer): string;
begin
  Result := Copy(S, From, Count);
end;

function StrCopyTail(const S: string; From: Integer): string;
begin
  Result := Copy(S, From, MaxInt);
end;

function StrHead(const S: string; N: Integer): string;
begin
  Result := Copy(S, 0, N);
end;

function StrPos(const Sub, S: string): Integer;
begin
  Result := Pos(Sub, S);
end;

function StripUnderscores(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(S) - 1 do
    if StrAt(S, I) <> Ord('_') then
      Result := Result + Chr(StrAt(S, I));
end;

function ParseIntLiteral(const S: string): Int64;
var
  I, Len: Integer;
  Digits:  string;
  C:       Integer;
  Prefix:  Integer;
  Digit:   Integer;
begin
  Len := Length(S);
  if Len = 0 then
    raise EConvertError.Create('Empty integer literal');

  Prefix := StrAt(S, 0);

  { Strip underscores from digit portion, validate placement }
  Digits := '';
  if (Prefix = Ord('$')) or (Prefix = Ord('%')) or (Prefix = Ord('&')) then
    I := 1   { skip prefix char }
  else
    I := 0;

  { First digit after prefix must not be underscore }
  if (I < Len) and (StrAt(S, I) = Ord('_')) then
    raise EConvertError.Create('Invalid integer literal: underscore at start of digits in ''' + S + '''');

  while I < Len do
  begin
    C := StrAt(S, I);
    if C <> Ord('_') then
      Digits := Digits + Chr(C);
    { Trailing underscore: this is '_' and next position is end-of-string }
    if (C = Ord('_')) and (I + 1 = Len) then
      raise EConvertError.Create('Invalid integer literal: trailing underscore in ''' + S + '''');
    Inc(I);
  end;

  if Digits = '' then
    raise EConvertError.Create('Invalid integer literal: no digits in ''' + S + '''');

  case Prefix of
    Ord('$'):
      begin
        Result := StrToInt64('$' + Digits);
      end;
    Ord('%'):
      begin
        Result := 0;
        for I := 0 to Length(Digits) - 1 do
        begin
          C := StrAt(Digits, I);
          if (C <> Ord('0')) and (C <> Ord('1')) then
            raise EConvertError.Create('Invalid binary digit in ''' + S + '''');
          Result := Result * 2 + (C - Ord('0'));
        end;
      end;
    Ord('&'):
      begin
        Result := 0;
        for I := 0 to Length(Digits) - 1 do
        begin
          C := StrAt(Digits, I);
          Digit := C - Ord('0');
          if (Digit < 0) or (Digit > 7) then
            raise EConvertError.Create('Invalid octal digit in ''' + S + '''');
          Result := Result * 8 + Digit;
        end;
      end;
  else
    Result := StrToInt64(Digits);
  end;
end;

end.
