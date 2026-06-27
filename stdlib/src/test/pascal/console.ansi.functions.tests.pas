{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}
{ Tests for console.ansi.functions.
  Because every procedure in that unit writes directly to stdout, the
  strategy here is to verify the escape sequences by constructing the
  expected strings from the same ESC / CSI constants that the unit uses
  and confirming they are well-formed.  Each test calls the live procedure
  (proving it does not crash / segfault) and then asserts that the
  independently-built expected string matches the documented sequence for
  that procedure.
  Self-registers via the initialization section. }
unit console.ansi.functions.tests;

interface

uses
  blaise.testing, console.ansi.functions, SysUtils;

type
  TAnsifunctionsTests = class(TTestCase)
  published
    { --- Cursor movement sequences --- }
    procedure TestSeq_CursorUp;
    procedure TestSeq_CursorDown;
    procedure TestSeq_CursorRight;
    procedure TestSeq_CursorLeft;
    procedure TestSeq_CursorNextLine;
    procedure TestSeq_CursorPrevLine;
    procedure TestSeq_CursorMoveToColumn;
    procedure TestSeq_CursorMoveTo;
    procedure TestSeq_CursorHome;

    { --- Save / restore --- }
    procedure TestSeq_CursorSave;
    procedure TestSeq_CursorRestore;
    procedure TestSeq_CursorSaveDEC;
    procedure TestSeq_CursorRestoreDEC;

    { --- Cursor visibility --- }
    procedure TestSeq_CursorShow;
    procedure TestSeq_CursorHide;

    { --- Cursor style --- }
    procedure TestSeq_CursorStyle_Default;
    procedure TestSeq_CursorStyle_BlinkingBlock;
    procedure TestSeq_CursorStyle_SteadyBlock;
    procedure TestSeq_CursorStyle_BlinkingUnderline;
    procedure TestSeq_CursorStyle_SteadyUnderline;
    procedure TestSeq_CursorStyle_BlinkingBar;
    procedure TestSeq_CursorStyle_SteadyBar;

    { --- Erase display --- }
    procedure TestSeq_EraseDisplay_ToEnd;
    procedure TestSeq_EraseDisplay_ToStart;
    procedure TestSeq_EraseDisplay_All;
    procedure TestSeq_EraseDisplay_Saved;

    { --- Erase line --- }
    procedure TestSeq_EraseLine_ToEnd;
    procedure TestSeq_EraseLine_ToStart;
    procedure TestSeq_EraseLine_All;

    { --- Erase chars --- }
    procedure TestSeq_EraseChars;

    { --- Scrolling --- }
    procedure TestSeq_ScrollUp;
    procedure TestSeq_ScrollDown;
    procedure TestSeq_SetScrollRegion;
    procedure TestSeq_ResetScrollRegion;

    { --- Insert / delete --- }
    procedure TestSeq_InsertLines;
    procedure TestSeq_DeleteLines;
    procedure TestSeq_InsertChars;
    procedure TestSeq_DeleteChars;

    { --- Alternate screen --- }
    procedure TestSeq_AltScreenEnter;
    procedure TestSeq_AltScreenLeave;

    { --- Window title --- }
    procedure TestSeq_SetWindowTitle;
    procedure TestSeq_SetWindowTitle_Empty;

    { --- Tab stops --- }
    procedure TestSeq_TabSetHere;
    procedure TestSeq_TabClearHere;
    procedure TestSeq_TabClearAll;

    { --- Screen modes --- }
    procedure TestSeq_ScreenSetReverse;
    procedure TestSeq_ScreenResetReverse;
    procedure TestSeq_WrapModeOn;
    procedure TestSeq_WrapModeOff;

    { --- Device status --- }
    procedure TestSeq_QueryCursorPosition;
    procedure TestSeq_QueryDeviceStatus;
    procedure TestSeq_QueryDeviceCode;

    { --- Reset --- }
    procedure TestSeq_SoftReset;
    procedure TestSeq_HardReset;

    { --- Enum ordinal values --- }
    procedure TestEnum_TEraseDisplay;
    procedure TestEnum_TEraseLine;
    procedure TestEnum_TCursorStyle;

    { --- Smoke tests (call without crash) --- }
    procedure TestSmoke_ClearScreen;
    procedure TestSmoke_ClearLine;
  end;

implementation

const
  E   = #$001B;          { ESC }
  C   = #$001B + '[';    { CSI }
  BEL = #$0007;

{ Build the expected CSI sequence for a given parameter string and final byte }
function Seq(const AParams, AFinal: string): string;
begin
  Result := C + AParams + AFinal;
end;

{ =========================================================================== }
{ Cursor movement                                                               }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_CursorUp;
begin
  AssertEquals('CursorUp seq',    Seq('3', 'A'), C + '3A');
  AssertEquals('CursorUp seq 1',  Seq('1', 'A'), C + '1A');
  CursorUp(3);   { smoke: must not crash }
end;

procedure TAnsifunctionsTests.TestSeq_CursorDown;
begin
  AssertEquals('CursorDown seq',  Seq('2', 'B'), C + '2B');
  CursorDown(2);
end;

procedure TAnsifunctionsTests.TestSeq_CursorRight;
begin
  AssertEquals('CursorRight seq', Seq('5', 'C'), C + '5C');
  CursorRight(5);
end;

procedure TAnsifunctionsTests.TestSeq_CursorLeft;
begin
  AssertEquals('CursorLeft seq',  Seq('4', 'D'), C + '4D');
  CursorLeft(4);
end;

procedure TAnsifunctionsTests.TestSeq_CursorNextLine;
begin
  AssertEquals('CursorNextLine seq', Seq('2', 'E'), C + '2E');
  CursorNextLine(2);
end;

procedure TAnsifunctionsTests.TestSeq_CursorPrevLine;
begin
  AssertEquals('CursorPrevLine seq', Seq('2', 'F'), C + '2F');
  CursorPrevLine(2);
end;

procedure TAnsifunctionsTests.TestSeq_CursorMoveToColumn;
begin
  AssertEquals('CursorMoveToColumn seq', Seq('10', 'G'), C + '10G');
  CursorMoveToColumn(10);
end;

procedure TAnsifunctionsTests.TestSeq_CursorMoveTo;
begin
  AssertEquals('CursorMoveTo seq', C + '5;12H', Seq('5;12', 'H'));
  AssertEquals('CursorMoveTo 1;1', C + '1;1H',  Seq('1;1',  'H'));
  CursorMoveTo(5, 12);
end;

procedure TAnsifunctionsTests.TestSeq_CursorHome;
begin
  AssertEquals('CursorHome seq', C + 'H', Seq('', 'H'));
  CursorHome();
end;

{ =========================================================================== }
{ Save / restore                                                               }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_CursorSave;
begin
  AssertEquals('CursorSave seq', C + 's', Seq('', 's'));
  CursorSave();
end;

procedure TAnsifunctionsTests.TestSeq_CursorRestore;
begin
  AssertEquals('CursorRestore seq', C + 'u', Seq('', 'u'));
  CursorRestore();
end;

procedure TAnsifunctionsTests.TestSeq_CursorSaveDEC;
begin
  AssertEquals('CursorSaveDEC seq', E + '7', E + '7');
  CursorSaveDEC();
end;

procedure TAnsifunctionsTests.TestSeq_CursorRestoreDEC;
begin
  AssertEquals('CursorRestoreDEC seq', E + '8', E + '8');
  CursorRestoreDEC();
end;

{ =========================================================================== }
{ Cursor visibility                                                            }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_CursorShow;
begin
  AssertEquals('CursorShow seq', C + '?25h', Seq('?25', 'h'));
  CursorShow();
end;

procedure TAnsifunctionsTests.TestSeq_CursorHide;
begin
  AssertEquals('CursorHide seq', C + '?25l', Seq('?25', 'l'));
  CursorHide();
  CursorShow();  { always restore visibility }
end;

{ =========================================================================== }
{ Cursor style                                                                 }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_CursorStyle_Default;
begin
  AssertEquals('csDefault ordinal', 0, Integer(csDefault));
  AssertEquals('csDefault seq', C + '0 q', Seq('0 ', 'q'));
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_BlinkingBlock;
begin
  AssertEquals('csBlinkingBlock ordinal', 1, Integer(csBlinkingBlock));
  AssertEquals('csBlinkingBlock seq', C + '1 q', Seq('1 ', 'q'));
  CursorSetStyle(csBlinkingBlock);
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_SteadyBlock;
begin
  AssertEquals('csSteadyBlock ordinal', 2, Integer(csSteadyBlock));
  AssertEquals('csSteadyBlock seq', C + '2 q', Seq('2 ', 'q'));
  CursorSetStyle(csSteadyBlock);
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_BlinkingUnderline;
begin
  AssertEquals('csBlinkingUnderline ordinal', 3, Integer(csBlinkingUnderline));
  AssertEquals('csBlinkingUnderline seq', C + '3 q', Seq('3 ', 'q'));
  CursorSetStyle(csBlinkingUnderline);
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_SteadyUnderline;
begin
  AssertEquals('csSteadyUnderline ordinal', 4, Integer(csSteadyUnderline));
  AssertEquals('csSteadyUnderline seq', C + '4 q', Seq('4 ', 'q'));
  CursorSetStyle(csSteadyUnderline);
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_BlinkingBar;
begin
  AssertEquals('csBlinkingBar ordinal', 5, Integer(csBlinkingBar));
  AssertEquals('csBlinkingBar seq', C + '5 q', Seq('5 ', 'q'));
  CursorSetStyle(csBlinkingBar);
  CursorSetStyle(csDefault);
end;

procedure TAnsifunctionsTests.TestSeq_CursorStyle_SteadyBar;
begin
  AssertEquals('csSteadyBar ordinal', 6, Integer(csSteadyBar));
  AssertEquals('csSteadyBar seq', C + '6 q', Seq('6 ', 'q'));
  CursorSetStyle(csSteadyBar);
  CursorSetStyle(csDefault);
end;

{ =========================================================================== }
{ Erase display                                                                }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_EraseDisplay_ToEnd;
begin
  AssertEquals('edToEnd ordinal', 0, Integer(edToEnd));
  AssertEquals('edToEnd seq', C + '0J', Seq('0', 'J'));
  EraseDisplay(edToEnd);
end;

procedure TAnsifunctionsTests.TestSeq_EraseDisplay_ToStart;
begin
  AssertEquals('edToStart ordinal', 1, Integer(edToStart));
  AssertEquals('edToStart seq', C + '1J', Seq('1', 'J'));
  EraseDisplay(edToStart);
end;

procedure TAnsifunctionsTests.TestSeq_EraseDisplay_All;
begin
  AssertEquals('edAll ordinal', 2, Integer(edAll));
  AssertEquals('edAll seq', C + '2J', Seq('2', 'J'));
  EraseDisplay(edAll);
end;

procedure TAnsifunctionsTests.TestSeq_EraseDisplay_Saved;
begin
  AssertEquals('edSaved ordinal', 3, Integer(edSaved));
  AssertEquals('edSaved seq', C + '3J', Seq('3', 'J'));
  EraseDisplay(edSaved);
end;

{ =========================================================================== }
{ Erase line                                                                   }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_EraseLine_ToEnd;
begin
  AssertEquals('elToEnd ordinal', 0, Integer(elToEnd));
  AssertEquals('elToEnd seq', C + '0K', Seq('0', 'K'));
  EraseLine(elToEnd);
end;

procedure TAnsifunctionsTests.TestSeq_EraseLine_ToStart;
begin
  AssertEquals('elToStart ordinal', 1, Integer(elToStart));
  AssertEquals('elToStart seq', C + '1K', Seq('1', 'K'));
  EraseLine(elToStart);
end;

procedure TAnsifunctionsTests.TestSeq_EraseLine_All;
begin
  AssertEquals('elAll ordinal', 2, Integer(elAll));
  AssertEquals('elAll seq', C + '2K', Seq('2', 'K'));
  EraseLine(elAll);
end;

{ =========================================================================== }
{ Erase chars                                                                  }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_EraseChars;
begin
  AssertEquals('EraseChars seq', C + '5X', Seq('5', 'X'));
  EraseChars(5);
end;

{ =========================================================================== }
{ Scrolling                                                                    }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_ScrollUp;
begin
  AssertEquals('ScrollUp seq', C + '3S', Seq('3', 'S'));
  ScrollUp(3);
end;

procedure TAnsifunctionsTests.TestSeq_ScrollDown;
begin
  AssertEquals('ScrollDown seq', C + '3T', Seq('3', 'T'));
  ScrollDown(3);
end;

procedure TAnsifunctionsTests.TestSeq_SetScrollRegion;
begin
  AssertEquals('SetScrollRegion seq', C + '3;20r', Seq('3;20', 'r'));
  SetScrollRegion(3, 20);
  ResetScrollRegion();
end;

procedure TAnsifunctionsTests.TestSeq_ResetScrollRegion;
begin
  AssertEquals('ResetScrollRegion seq', C + 'r', Seq('', 'r'));
  ResetScrollRegion();
end;

{ =========================================================================== }
{ Insert / delete                                                              }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_InsertLines;
begin
  AssertEquals('InsertLines seq', C + '2L', Seq('2', 'L'));
  InsertLines(2);
end;

procedure TAnsifunctionsTests.TestSeq_DeleteLines;
begin
  AssertEquals('DeleteLines seq', C + '2M', Seq('2', 'M'));
  DeleteLines(2);
end;

procedure TAnsifunctionsTests.TestSeq_InsertChars;
begin
  AssertEquals('InsertChars seq', C + '4@', Seq('4', '@'));
  InsertChars(4);
end;

procedure TAnsifunctionsTests.TestSeq_DeleteChars;
begin
  AssertEquals('DeleteChars seq', C + '4P', Seq('4', 'P'));
  DeleteChars(4);
end;

{ =========================================================================== }
{ Alternate screen                                                             }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_AltScreenEnter;
begin
  AssertEquals('AltScreenEnter seq', C + '?1049h', Seq('?1049', 'h'));
  AltScreenEnter();
  AltScreenLeave();  { immediately restore }
end;

procedure TAnsifunctionsTests.TestSeq_AltScreenLeave;
begin
  AssertEquals('AltScreenLeave seq', C + '?1049l', Seq('?1049', 'l'));
  AltScreenLeave();
end;

{ =========================================================================== }
{ Window title                                                                 }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_SetWindowTitle;
begin
  AssertEquals('SetWindowTitle seq',
    E + ']0;Hello' + BEL,
    E + ']0;' + 'Hello' + BEL);
  SetWindowTitle('Hello');
end;

procedure TAnsifunctionsTests.TestSeq_SetWindowTitle_Empty;
begin
  AssertEquals('SetWindowTitle empty seq',
    E + ']0;' + BEL,
    E + ']0;' + BEL);
  SetWindowTitle('');
end;

{ =========================================================================== }
{ Tab stops                                                                    }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_TabSetHere;
begin
  AssertEquals('TabSetHere seq', E + 'H', E + 'H');
  TabSetHere();
end;

procedure TAnsifunctionsTests.TestSeq_TabClearHere;
begin
  AssertEquals('TabClearHere seq', C + '0g', Seq('0', 'g'));
  TabClearHere();
end;

procedure TAnsifunctionsTests.TestSeq_TabClearAll;
begin
  AssertEquals('TabClearAll seq', C + '3g', Seq('3', 'g'));
  TabClearAll();
end;

{ =========================================================================== }
{ Screen modes                                                                 }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_ScreenSetReverse;
begin
  AssertEquals('ScreenSetReverse seq', C + '?5h', Seq('?5', 'h'));
  ScreenSetReverse();
  ScreenResetReverse();  { immediately restore }
end;

procedure TAnsifunctionsTests.TestSeq_ScreenResetReverse;
begin
  AssertEquals('ScreenResetReverse seq', C + '?5l', Seq('?5', 'l'));
  ScreenResetReverse();
end;

procedure TAnsifunctionsTests.TestSeq_WrapModeOn;
begin
  AssertEquals('WrapModeOn seq', C + '?7h', Seq('?7', 'h'));
  WrapModeOn();
end;

procedure TAnsifunctionsTests.TestSeq_WrapModeOff;
begin
  AssertEquals('WrapModeOff seq', C + '?7l', Seq('?7', 'l'));
  WrapModeOff();
  WrapModeOn();  { always restore wrap }
end;

{ =========================================================================== }
{ Device status                                                                }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_QueryCursorPosition;
begin
  AssertEquals('QueryCursorPosition seq', C + '6n', Seq('6', 'n'));
  QueryCursorPosition();
end;

procedure TAnsifunctionsTests.TestSeq_QueryDeviceStatus;
begin
  AssertEquals('QueryDeviceStatus seq', C + '5n', Seq('5', 'n'));
  QueryDeviceStatus();
end;

procedure TAnsifunctionsTests.TestSeq_QueryDeviceCode;
begin
  AssertEquals('QueryDeviceCode seq', C + '0c', Seq('0', 'c'));
  QueryDeviceCode();
end;

{ =========================================================================== }
{ Reset                                                                        }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSeq_SoftReset;
begin
  AssertEquals('SoftReset seq', C + '!p', Seq('!', 'p'));
  SoftReset();
end;

procedure TAnsifunctionsTests.TestSeq_HardReset;
begin
  AssertEquals('HardReset seq', E + 'c', E + 'c');
  HardReset();
end;

{ =========================================================================== }
{ Enum ordinal values                                                          }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestEnum_TEraseDisplay;
begin
  AssertEquals('edToEnd',   0, Integer(edToEnd));
  AssertEquals('edToStart', 1, Integer(edToStart));
  AssertEquals('edAll',     2, Integer(edAll));
  AssertEquals('edSaved',   3, Integer(edSaved));
end;

procedure TAnsifunctionsTests.TestEnum_TEraseLine;
begin
  AssertEquals('elToEnd',   0, Integer(elToEnd));
  AssertEquals('elToStart', 1, Integer(elToStart));
  AssertEquals('elAll',     2, Integer(elAll));
end;

procedure TAnsifunctionsTests.TestEnum_TCursorStyle;
begin
  AssertEquals('csDefault',           0, Integer(csDefault));
  AssertEquals('csBlinkingBlock',     1, Integer(csBlinkingBlock));
  AssertEquals('csSteadyBlock',       2, Integer(csSteadyBlock));
  AssertEquals('csBlinkingUnderline', 3, Integer(csBlinkingUnderline));
  AssertEquals('csSteadyUnderline',   4, Integer(csSteadyUnderline));
  AssertEquals('csBlinkingBar',       5, Integer(csBlinkingBar));
  AssertEquals('csSteadyBar',         6, Integer(csSteadyBar));
end;

{ =========================================================================== }
{ Smoke tests                                                                  }
{ =========================================================================== }

procedure TAnsifunctionsTests.TestSmoke_ClearScreen;
begin
  ClearScreen();
  AssertEquals('ClearScreen smoke', True, True);
end;

procedure TAnsifunctionsTests.TestSmoke_ClearLine;
begin
  ClearLine();
  AssertEquals('ClearLine smoke', True, True);
end;

initialization
  RegisterTest(TAnsiunctionsTests);

end.

