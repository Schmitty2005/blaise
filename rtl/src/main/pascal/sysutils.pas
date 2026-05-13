{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit SysUtils;

// Blaise RTL — SysUtils unit.
//
// Provides the Exception base class, PathDelim (Delphi compat alias for
// DirectorySeparator), and the BoolToStr helper.
//
// LineEnding, sLineBreak, DirectorySeparator, and PathSeparator are defined
// in system.pas — they are platform fundamentals, not SysUtils concerns.
//
// Functions that are already compiler built-ins (FileExists, DeleteFile,
// RenameFile, SetCurrentDir, ExtractFileExt, IntToStr, StrToInt, Format,
// UpperCase, LowerCase, Trim, CompareStr, CompareText, SameText, etc.) are
// deliberately absent from this interface.  Re-declaring them here would
// shadow the built-ins and produce a duplicate-identifier error at compile time.

interface

const
  { Delphi compatibility alias for system.DirectorySeparator. }
  PathDelim = '/';

type
  Exception = class
    FMessage: string;
    constructor Create(AMessage: string);
    property Message: string read FMessage;
  end;

  EInOutError = class(Exception)
  end;

  EConvertError = class(Exception)
  end;

{ BoolToStr — not a compiler built-in; pure Pascal implementation }
function BoolToStr(B: Boolean; AUseBoolStrs: Boolean = False): string;

implementation

constructor Exception.Create(AMessage: string);
begin
  Self.FMessage := AMessage
end;

function BoolToStr(B: Boolean; AUseBoolStrs: Boolean): string;
begin
  if B then
    Result := 'True'
  else
    Result := 'False'
end;

end.
