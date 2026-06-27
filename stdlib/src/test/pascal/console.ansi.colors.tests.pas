{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}
{ Tests for the console.ansi.colors unit.  Verifies that each color/style
  method produces the correct ANSI SGR escape sequence, and that chaining,
  Reset(), and the 256/RGB sub-commands all emit the expected bytes.
  Self-registers via the initialization section. }
unit console.ansi.colors.Tests;

interface

uses
  blaise.testing, console.ansi.colors;

type
  TAnsiColorTests = class(TTestCase)
  published
    { --- Basic foreground colors --- }
    procedure TestFg_Black;
    procedure TestFg_Red;
    procedure TestFg_Green;
    procedure TestFg_Yellow;
    procedure TestFg_Blue;
    procedure TestFg_Magenta;
    procedure TestFg_Cyan;
    procedure TestFg_White;

    { --- Bright foreground colors --- }
    procedure TestFg_BrightBlack;
    procedure TestFg_BrightRed;
    procedure TestFg_BrightGreen;
    procedure TestFg_BrightYellow;
    procedure TestFg_BrightBlue;
    procedure TestFg_BrightMagenta;
    procedure TestFg_BrightCyan;
    procedure TestFg_BrightWhite;

    { --- Standard background colors --- }
    procedure TestBg_Black;
    procedure TestBg_Red;
    procedure TestBg_Green;
    procedure TestBg_Yellow;
    procedure TestBg_Blue;
    procedure TestBg_Magenta;
    procedure TestBg_Cyan;
    procedure TestBg_White;

    { --- Bright background colors --- }
    procedure TestBg_BrightBlack;
    procedure TestBg_BrightRed;
    procedure TestBg_BrightGreen;
    procedure TestBg_BrightYellow;
    procedure TestBg_BrightBlue;
    procedure TestBg_BrightMagenta;
    procedure TestBg_BrightCyan;
    procedure TestBg_BrightWhite;

    { --- Text attributes --- }
    procedure TestAttr_Bold;
    procedure TestAttr_Dim;
    procedure TestAttr_Italic;
    procedure TestAttr_Underline;
    procedure TestAttr_Blink;
    procedure TestAttr_Inverse;
    procedure TestAttr_Hidden;
    procedure TestAttr_Strikethrough;

    { --- Chaining --- }
    procedure TestChain_FgBold;
    procedure TestChain_FgBgAttr;

    { --- Reset --- }
    procedure TestReset_ClearsCodes;
    procedure TestReset_NoCodesReturnsPlainText;

    { --- 256-color --- }
    procedure TestColor256_Fg;
    procedure TestColor256_Bg;

    { --- True-color RGB --- }
    procedure TestColorRGB_Fg;
    procedure TestColorRGB_Bg;

    { --- Text with no codes --- }
    procedure TestText_NoCodes;
  end;

implementation

const
  ESC   = #$001B;
  RESET = #$001B + '[0m';

{ Helper: builds the expected sequence for a single-segment SGR code }
function Expect(const ACodes, AText: string): string;
begin
  Result := ESC + '[' + ACodes + 'm' + AText + RESET;
end;

{ =========================================================================== }
{ Standard foreground                                                          }
{ =========================================================================== }

procedure TAnsiColorTests.TestFg_Black;
begin
  AssertEquals('Black', Expect('30', 'x'), Ansi.Reset().Black().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Red;
begin
  AssertEquals('Red', Expect('31', 'x'), Ansi.Reset().Red().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Green;
begin
  AssertEquals('Green', Expect('32', 'x'), Ansi.Reset().Green().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Yellow;
begin
  AssertEquals('Yellow', Expect('33', 'x'), Ansi.Reset().Yellow().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Blue;
begin
  AssertEquals('Blue', Expect('34', 'x'), Ansi.Reset().Blue().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Magenta;
begin
  AssertEquals('Magenta', Expect('35', 'x'), Ansi.Reset().Magenta().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_Cyan;
begin
  AssertEquals('Cyan', Expect('36', 'x'), Ansi.Reset().Cyan().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_White;
begin
  AssertEquals('White', Expect('37', 'x'), Ansi.Reset().White().Text('x').ToString());
end;

{ =========================================================================== }
{ Bright foreground                                                            }
{ =========================================================================== }

procedure TAnsiColorTests.TestFg_BrightBlack;
begin
  AssertEquals('BrightBlack', Expect('90', 'x'), Ansi.Reset().BrightBlack().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightRed;
begin
  AssertEquals('BrightRed', Expect('91', 'x'), Ansi.Reset().BrightRed().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightGreen;
begin
  AssertEquals('BrightGreen', Expect('92', 'x'), Ansi.Reset().BrightGreen().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightYellow;
begin
  AssertEquals('BrightYellow', Expect('93', 'x'), Ansi.Reset().BrightYellow().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightBlue;
begin
  AssertEquals('BrightBlue', Expect('94', 'x'), Ansi.Reset().BrightBlue().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightMagenta;
begin
  AssertEquals('BrightMagenta', Expect('95', 'x'), Ansi.Reset().BrightMagenta().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightCyan;
begin
  AssertEquals('BrightCyan', Expect('96', 'x'), Ansi.Reset().BrightCyan().Text('x').ToString());
end;

procedure TAnsiColorTests.TestFg_BrightWhite;
begin
  AssertEquals('BrightWhite', Expect('97', 'x'), Ansi.Reset().BrightWhite().Text('x').ToString());
end;

{ =========================================================================== }
{ Standard background                                                          }
{ =========================================================================== }

procedure TAnsiColorTests.TestBg_Black;
begin
  AssertEquals('BgBlack', Expect('40', 'x'), Ansi.Reset().BgBlack().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Red;
begin
  AssertEquals('BgRed', Expect('41', 'x'), Ansi.Reset().BgRed().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Green;
begin
  AssertEquals('BgGreen', Expect('42', 'x'), Ansi.Reset().BgGreen().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Yellow;
begin
  AssertEquals('BgYellow', Expect('43', 'x'), Ansi.Reset().BgYellow().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Blue;
begin
  AssertEquals('BgBlue', Expect('44', 'x'), Ansi.Reset().BgBlue().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Magenta;
begin
  AssertEquals('BgMagenta', Expect('45', 'x'), Ansi.Reset().BgMagenta().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_Cyan;
begin
  AssertEquals('BgCyan', Expect('46', 'x'), Ansi.Reset().BgCyan().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_White;
begin
  AssertEquals('BgWhite', Expect('47', 'x'), Ansi.Reset().BgWhite().Text('x').ToString());
end;

{ =========================================================================== }
{ Bright background                                                            }
{ =========================================================================== }

procedure TAnsiColorTests.TestBg_BrightBlack;
begin
  AssertEquals('BgBrightBlack', Expect('100', 'x'), Ansi.Reset().BgBrightBlack().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightRed;
begin
  AssertEquals('BgBrightRed', Expect('101', 'x'), Ansi.Reset().BgBrightRed().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightGreen;
begin
  AssertEquals('BgBrightGreen', Expect('102', 'x'), Ansi.Reset().BgBrightGreen().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightYellow;
begin
  AssertEquals('BgBrightYellow', Expect('103', 'x'), Ansi.Reset().BgBrightYellow().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightBlue;
begin
  AssertEquals('BgBrightBlue', Expect('104', 'x'), Ansi.Reset().BgBrightBlue().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightMagenta;
begin
  AssertEquals('BgBrightMagenta', Expect('105', 'x'), Ansi.Reset().BgBrightMagenta().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightCyan;
begin
  AssertEquals('BgBrightCyan', Expect('106', 'x'), Ansi.Reset().BgBrightCyan().Text('x').ToString());
end;

procedure TAnsiColorTests.TestBg_BrightWhite;
begin
  AssertEquals('BgBrightWhite', Expect('107', 'x'), Ansi.Reset().BgBrightWhite().Text('x').ToString());
end;

{ =========================================================================== }
{ Text attributes                                                              }
{ =========================================================================== }

procedure TAnsiColorTests.TestAttr_Bold;
begin
  AssertEquals('Bold', Expect('1', 'x'), Ansi.Reset().Bold().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Dim;
begin
  AssertEquals('Dim', Expect('2', 'x'), Ansi.Reset().Dim().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Italic;
begin
  AssertEquals('Italic', Expect('3', 'x'), Ansi.Reset().Italic().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Underline;
begin
  AssertEquals('Underline', Expect('4', 'x'), Ansi.Reset().Underline().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Blink;
begin
  AssertEquals('Blink', Expect('5', 'x'), Ansi.Reset().Blink().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Inverse;
begin
  AssertEquals('Inverse', Expect('7', 'x'), Ansi.Reset().Inverse().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Hidden;
begin
  AssertEquals('Hidden', Expect('8', 'x'), Ansi.Reset().Hidden().Text('x').ToString());
end;

procedure TAnsiColorTests.TestAttr_Strikethrough;
begin
  AssertEquals('Strikethrough', Expect('9', 'x'), Ansi.Reset().Strikethrough().Text('x').ToString());
end;

{ =========================================================================== }
{ Chaining                                                                     }
{ =========================================================================== }

procedure TAnsiColorTests.TestChain_FgBold;
begin
  { Red (31) then Bold (1) → ESC[31;1m }
  AssertEquals('Red+Bold', Expect('31;1', 'hi'), Ansi.Reset().Red().Bold().Text('hi').ToString());
end;

procedure TAnsiColorTests.TestChain_FgBgAttr;
begin
  { Green fg (32) + BgBlue bg (44) + Underline (4) → ESC[32;44;4m }
  AssertEquals('Green+BgBlue+Underline',
    Expect('32;44;4', 'hi'),
    Ansi.Reset().Green().BgBlue().Underline().Text('hi').ToString());
end;

{ =========================================================================== }
{ Reset                                                                        }
{ =========================================================================== }

procedure TAnsiColorTests.TestReset_ClearsCodes;
begin
  { Accumulate some codes, then Reset() and apply only one new code }
  Ansi.Red().Bold().BgWhite();
  Ansi.Reset();
  AssertEquals('Reset clears',
    Expect('32', 'x'),
    Ansi.Green().Text('x').ToString());
end;

procedure TAnsiColorTests.TestReset_NoCodesReturnsPlainText;
begin
  { After Reset() with no further codes, ToString() returns plain text }
  AssertEquals('No codes plain text', 'hello', Ansi.Reset().Text('hello').ToString());
end;

{ =========================================================================== }
{ 256-color                                                                    }
{ =========================================================================== }

procedure TAnsiColorTests.TestColor256_Fg;
begin
  { ESC[38;5;196m — pure red in the 256 palette }
  AssertEquals('Color256 fg', Expect('38;5;196', 'x'), Ansi.Reset().Color256(196).Text('x').ToString());
end;

procedure TAnsiColorTests.TestColor256_Bg;
begin
  { ESC[48;5;21m — pure blue background }
  AssertEquals('Color256 bg', Expect('48;5;21', 'x'), Ansi.Reset().BgColor256(21).Text('x').ToString());
end;

{ =========================================================================== }
{ True-color RGB                                                               }
{ =========================================================================== }

procedure TAnsiColorTests.TestColorRGB_Fg;
begin
  { ESC[38;2;255;128;0m — orange foreground }
  AssertEquals('ColorRGB fg',
    Expect('38;2;255;128;0', 'x'),
    Ansi.Reset().ColorRGB(255, 128, 0).Text('x').ToString());
end;

procedure TAnsiColorTests.TestColorRGB_Bg;
begin
  { ESC[48;2;0;0;128m — navy background }
  AssertEquals('BgColorRGB',
    Expect('48;2;0;0;128', 'x'),
    Ansi.Reset().BgColorRGB(0, 0, 128).Text('x').ToString());
end;

{ =========================================================================== }
{ Text with no codes                                                           }
{ =========================================================================== }

procedure TAnsiColorTests.TestText_NoCodes;
begin
  { A freshly reset builder with only Text() set must return the plain string }
  AssertEquals('plain text', 'hello world', Ansi.Reset().Text('hello world').ToString());
end;

initialization
  RegisterTest(TAnsiColorTests);

end.

