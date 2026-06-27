(******************************************************************************
 * Unit    : console.ansi.functions
 * Purpose : Procedural wrappers for every ANSI / VT100 terminal control
 *           sequence that is NOT covered by console.ansi.colors (i.e.
 *           everything except SGR color and text-attribute codes).
 *
 *           All procedures write directly to stdout via Write().
 *           Categories covered:
 *             - Cursor movement  (absolute, relative, save/restore)
 *             - Cursor visibility and style
 *             - Screen / line erasing
 *             - Scrolling
 *             - Alternate screen buffer
 *             - Window title
 *             - Tab stops
 *             - Keyboard / mode control
 *             - Device status queries
 *             - Terminal reset
 *
 *           Example:
 *             CursorMoveTo(5, 10);
 *             EraseDisplay(edAll);
 *             CursorShow();
 *
 * Author  : console.ansi contributors
 * Requires: SysUtils (IntToStr)
 ******************************************************************************)
unit console.ansi.functions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ =========================================================================== }
{ Enumerations                                                                 }
{ =========================================================================== }

type
  (**************************************************************************
   * TEraseDisplay
   * Parameter for EraseDisplay().
   *   edToEnd    ESC[0J  Erase from cursor to end of screen.
   *   edToStart  ESC[1J  Erase from cursor to beginning of screen.
   *   edAll      ESC[2J  Erase entire visible screen (cursor unchanged).
   *   edSaved    ESC[3J  Erase entire screen including scrollback buffer.
   **************************************************************************)
  TEraseDisplay = (edToEnd, edToStart, edAll, edSaved);

  (**************************************************************************
   * TEraseLine
   * Parameter for EraseLine().
   *   elToEnd    ESC[0K  Erase from cursor to end of line.
   *   elToStart  ESC[1K  Erase from cursor to beginning of line.
   *   elAll      ESC[2K  Erase entire line (cursor column unchanged).
   **************************************************************************)
  TEraseLine = (elToEnd, elToStart, elAll);

  (**************************************************************************
   * TCursorStyle
   * Parameter for CursorSetStyle().
   * Blink variants depend on terminal support.
   *   csDefault          ESC[0 q  Reset to terminal default.
   *   csBlinkingBlock    ESC[1 q  Blinking block.
   *   csSteadyBlock      ESC[2 q  Steady block.
   *   csBlinkingUnderline ESC[3 q Blinking underline.
   *   csSteadyUnderline  ESC[4 q  Steady underline.
   *   csBlinkingBar      ESC[5 q  Blinking I-beam bar.
   *   csSteadyBar        ESC[6 q  Steady I-beam bar.
   **************************************************************************)
  TCursorStyle = (csDefault, csBlinkingBlock, csSteadyBlock,
                  csBlinkingUnderline, csSteadyUnderline,
                  csBlinkingBar, csSteadyBar);

{ =========================================================================== }
{ Constants                                                                    }
{ =========================================================================== }

const
  (** The ESC character used to introduce all escape sequences. *)
  ESC = #$001B;

  (** CSI — Control Sequence Introducer: ESC followed by '['. *)
  CSI = #$001B + '[';

{ =========================================================================== }
{ Cursor movement                                                              }
{ =========================================================================== }

(******************************************************************************
 * CursorUp
 * Moves the cursor up by ACount lines.  Stops at the top margin.
 * Emits ESC[<n>A.
 * @param ACount  Number of lines to move (default 1).
 ******************************************************************************)
procedure CursorUp(ACount: Integer);

(******************************************************************************
 * CursorDown
 * Moves the cursor down by ACount lines.  Stops at the bottom margin.
 * Emits ESC[<n>B.
 * @param ACount  Number of lines to move (default 1).
 ******************************************************************************)
procedure CursorDown(ACount: Integer);

(******************************************************************************
 * CursorRight
 * Moves the cursor right (forward) by ACount columns.
 * Emits ESC[<n>C.
 * @param ACount  Number of columns to move (default 1).
 ******************************************************************************)
procedure CursorRight(ACount: Integer);

(******************************************************************************
 * CursorLeft
 * Moves the cursor left (backward) by ACount columns.
 * Emits ESC[<n>D.
 * @param ACount  Number of columns to move (default 1).
 ******************************************************************************)
procedure CursorLeft(ACount: Integer);

(******************************************************************************
 * CursorNextLine
 * Moves the cursor to the beginning of the line ACount lines down.
 * Emits ESC[<n>E.
 * @param ACount  Number of lines to move (default 1).
 ******************************************************************************)
procedure CursorNextLine(ACount: Integer);

(******************************************************************************
 * CursorPrevLine
 * Moves the cursor to the beginning of the line ACount lines up.
 * Emits ESC[<n>F.
 * @param ACount  Number of lines to move (default 1).
 ******************************************************************************)
procedure CursorPrevLine(ACount: Integer);

(******************************************************************************
 * CursorMoveToColumn
 * Moves the cursor to column ACol on the current line (1-based).
 * Emits ESC[<n>G.
 * @param ACol  Target column, 1 = leftmost.
 ******************************************************************************)
procedure CursorMoveToColumn(ACol: Integer);

(******************************************************************************
 * CursorMoveTo
 * Moves the cursor to an absolute position (1-based row and column).
 * Emits ESC[<row>;<col>H.
 * @param ARow  Target row,    1 = top of screen.
 * @param ACol  Target column, 1 = left of screen.
 ******************************************************************************)
procedure CursorMoveTo(ARow, ACol: Integer);

(******************************************************************************
 * CursorHome
 * Moves the cursor to the home position (row 1, column 1).
 * Emits ESC[H.
 ******************************************************************************)
procedure CursorHome();

(******************************************************************************
 * CursorSave
 * Saves the current cursor position and attributes (ANSI / SCO variant).
 * Emits ESC[s.
 * Use CursorRestore() to return to the saved position.
 ******************************************************************************)
procedure CursorSave();

(******************************************************************************
 * CursorRestore
 * Restores the cursor position and attributes saved by CursorSave().
 * Emits ESC[u.
 ******************************************************************************)
procedure CursorRestore();

(******************************************************************************
 * CursorSaveDEC
 * Saves the current cursor position (DEC / VT variant).
 * Emits ESC 7.
 ******************************************************************************)
procedure CursorSaveDEC();

(******************************************************************************
 * CursorRestoreDEC
 * Restores the cursor position saved by CursorSaveDEC().
 * Emits ESC 8.
 ******************************************************************************)
procedure CursorRestoreDEC();

{ =========================================================================== }
{ Cursor visibility                                                            }
{ =========================================================================== }

(******************************************************************************
 * CursorShow
 * Makes the cursor visible.
 * Emits ESC[?25h.
 ******************************************************************************)
procedure CursorShow();

(******************************************************************************
 * CursorHide
 * Makes the cursor invisible.
 * Emits ESC[?25l.
 * Always call CursorShow() before your program exits.
 ******************************************************************************)
procedure CursorHide();

(******************************************************************************
 * CursorSetStyle
 * Sets the cursor shape and blink state.
 * Emits ESC[<n> q  (DECSCUSR).
 * @param AStyle  One of the TCursorStyle values.
 ******************************************************************************)
procedure CursorSetStyle(AStyle: TCursorStyle);

{ =========================================================================== }
{ Erase                                                                        }
{ =========================================================================== }

(******************************************************************************
 * EraseDisplay
 * Erases part of or the entire display.
 * @param AMode  One of the TEraseDisplay values.
 ******************************************************************************)
procedure EraseDisplay(AMode: TEraseDisplay);

(******************************************************************************
 * EraseLine
 * Erases part of or the entire current line.  Cursor position is unchanged.
 * @param AMode  One of the TEraseLine values.
 ******************************************************************************)
procedure EraseLine(AMode: TEraseLine);

(******************************************************************************
 * EraseChars
 * Erases ACount characters starting at the cursor position, replacing them
 * with spaces.  Cursor position is unchanged.
 * Emits ESC[<n>X.
 * @param ACount  Number of characters to erase.
 ******************************************************************************)
procedure EraseChars(ACount: Integer);

{ =========================================================================== }
{ Scrolling                                                                    }
{ =========================================================================== }

(******************************************************************************
 * ScrollUp
 * Scrolls the page up by ACount lines.  New lines are added at the bottom.
 * Emits ESC[<n>S.
 * @param ACount  Number of lines to scroll (default 1).
 ******************************************************************************)
procedure ScrollUp(ACount: Integer);

(******************************************************************************
 * ScrollDown
 * Scrolls the page down by ACount lines.  New lines are added at the top.
 * Emits ESC[<n>T.
 * @param ACount  Number of lines to scroll (default 1).
 ******************************************************************************)
procedure ScrollDown(ACount: Integer);

(******************************************************************************
 * SetScrollRegion
 * Defines the top and bottom lines of the scrolling region (DECSTBM).
 * Emits ESC[<top>;<bottom>r.
 * @param ATop     First line of the scrolling region (1-based).
 * @param ABottom  Last  line of the scrolling region (1-based).
 ******************************************************************************)
procedure SetScrollRegion(ATop, ABottom: Integer);

(******************************************************************************
 * ResetScrollRegion
 * Removes the scroll region so the entire screen scrolls.
 * Emits ESC[r.
 ******************************************************************************)
procedure ResetScrollRegion();

{ =========================================================================== }
{ Insert / delete                                                              }
{ =========================================================================== }

(******************************************************************************
 * InsertLines
 * Inserts ACount blank lines at the cursor row, pushing existing lines down.
 * Emits ESC[<n>L.
 * @param ACount  Number of lines to insert (default 1).
 ******************************************************************************)
procedure InsertLines(ACount: Integer);

(******************************************************************************
 * DeleteLines
 * Deletes ACount lines starting at the cursor row, pulling remaining lines up.
 * Emits ESC[<n>M.
 * @param ACount  Number of lines to delete (default 1).
 ******************************************************************************)
procedure DeleteLines(ACount: Integer);

(******************************************************************************
 * InsertChars
 * Inserts ACount blank characters at the cursor position, shifting the rest
 * of the line right.
 * Emits ESC[<n>@.
 * @param ACount  Number of characters to insert (default 1).
 ******************************************************************************)
procedure InsertChars(ACount: Integer);

(******************************************************************************
 * DeleteChars
 * Deletes ACount characters at the cursor position, shifting the rest of
 * the line left.
 * Emits ESC[<n>P.
 * @param ACount  Number of characters to delete (default 1).
 ******************************************************************************)
procedure DeleteChars(ACount: Integer);

{ =========================================================================== }
{ Alternate screen buffer                                                      }
{ =========================================================================== }

(******************************************************************************
 * AltScreenEnter
 * Switches to the alternate screen buffer, saving the normal buffer.
 * The cursor position and screen content are restored when AltScreenLeave()
 * is called.
 * Emits ESC[?1049h.
 ******************************************************************************)
procedure AltScreenEnter();

(******************************************************************************
 * AltScreenLeave
 * Switches back to the normal screen buffer, restoring the saved content.
 * Emits ESC[?1049l.
 ******************************************************************************)
procedure AltScreenLeave();

{ =========================================================================== }
{ Window title                                                                 }
{ =========================================================================== }

(******************************************************************************
 * SetWindowTitle
 * Sets the terminal window title (xterm OSC sequence).
 * Emits ESC]0;<title>BEL.
 * Not all terminals support this; it is silently ignored where unsupported.
 * @param ATitle  The string to display as the window / tab title.
 ******************************************************************************)
procedure SetWindowTitle(const ATitle: string);

{ =========================================================================== }
{ Tab stops                                                                    }
{ =========================================================================== }

(******************************************************************************
 * TabSetHere
 * Sets a tab stop at the current cursor column.
 * Emits ESC H.
 ******************************************************************************)
procedure TabSetHere();

(******************************************************************************
 * TabClearHere
 * Clears the tab stop at the current cursor column.
 * Emits ESC[0g.
 ******************************************************************************)
procedure TabClearHere();

(******************************************************************************
 * TabClearAll
 * Clears all tab stops.
 * Emits ESC[3g.
 ******************************************************************************)
procedure TabClearAll();

{ =========================================================================== }
{ Screen modes                                                                 }
{ =========================================================================== }

(******************************************************************************
 * ScreenSetReverse
 * Enables reverse-video mode for the entire screen (DECSCNM).
 * Emits ESC[?5h.
 ******************************************************************************)
procedure ScreenSetReverse();

(******************************************************************************
 * ScreenResetReverse
 * Restores normal (non-reverse) video for the entire screen.
 * Emits ESC[?5l.
 ******************************************************************************)
procedure ScreenResetReverse();

(******************************************************************************
 * WrapModeOn
 * Enables automatic line wrap at the right margin (DECAWM).
 * Emits ESC[?7h.
 ******************************************************************************)
procedure WrapModeOn();

(******************************************************************************
 * WrapModeOff
 * Disables automatic line wrap; characters past the right margin overwrite
 * the last column.
 * Emits ESC[?7l.
 ******************************************************************************)
procedure WrapModeOff();

{ =========================================================================== }
{ Device status                                                                }
{ =========================================================================== }

(******************************************************************************
 * QueryCursorPosition
 * Asks the terminal to report the current cursor position.
 * Emits ESC[6n.
 * The terminal responds with ESC[<row>;<col>R on stdin; reading that
 * response is the caller's responsibility.
 ******************************************************************************)
procedure QueryCursorPosition();

(******************************************************************************
 * QueryDeviceStatus
 * Asks the terminal to report its operational status.
 * Emits ESC[5n.
 * The terminal responds with ESC[0n (OK) or ESC[3n (not OK).
 ******************************************************************************)
procedure QueryDeviceStatus();

(******************************************************************************
 * QueryDeviceCode
 * Asks the terminal to identify itself (DA — Device Attributes).
 * Emits ESC[0c.
 * The terminal responds with ESC[?1;<Ps>c.
 ******************************************************************************)
procedure QueryDeviceCode();

{ =========================================================================== }
{ Terminal reset                                                               }
{ =========================================================================== }

(******************************************************************************
 * SoftReset
 * Performs a soft reset of the terminal (DECSTR).
 * Resets SGR attributes, scroll region, cursor visibility, and various
 * mode settings without clearing the screen.
 * Emits ESC[!p.
 ******************************************************************************)
procedure SoftReset();

(******************************************************************************
 * HardReset
 * Performs a full terminal reset (RIS — Reset to Initial State).
 * Clears the screen, resets all settings to factory defaults, and reloads
 * character sets.
 * Emits ESC c.
 ******************************************************************************)
procedure HardReset();

{ =========================================================================== }
{ Convenience                                                                  }
{ =========================================================================== }

(******************************************************************************
 * ClearScreen
 * Clears the entire display and moves the cursor to the home position.
 * Equivalent to EraseDisplay(edAll) followed by CursorHome().
 ******************************************************************************)
procedure ClearScreen();

(******************************************************************************
 * ClearLine
 * Erases the entire current line without moving the cursor.
 * Equivalent to EraseLine(elAll).
 ******************************************************************************)
procedure ClearLine();

implementation

{ =========================================================================== }
{ Internal helper                                                              }
{ =========================================================================== }

(** Writes a complete CSI sequence to stdout: ESC [ <ASeq>. *)
procedure Emit(const ASeq: string);
begin
  Write(CSI + ASeq);
end;

{ =========================================================================== }
{ Cursor movement                                                              }
{ =========================================================================== }

procedure CursorUp(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'A');
end;

procedure CursorDown(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'B');
end;

procedure CursorRight(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'C');
end;

procedure CursorLeft(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'D');
end;

procedure CursorNextLine(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'E');
end;

procedure CursorPrevLine(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'F');
end;

procedure CursorMoveToColumn(ACol: Integer);
begin
  Emit(IntToStr(ACol) + 'G');
end;

procedure CursorMoveTo(ARow, ACol: Integer);
begin
  Emit(IntToStr(ARow) + ';' + IntToStr(ACol) + 'H');
end;

procedure CursorHome();
begin
  Emit('H');
end;

procedure CursorSave();
begin
  Emit('s');
end;

procedure CursorRestore();
begin
  Emit('u');
end;

procedure CursorSaveDEC();
begin
  Write(ESC + '7');
end;

procedure CursorRestoreDEC();
begin
  Write(ESC + '8');
end;

{ =========================================================================== }
{ Cursor visibility                                                            }
{ =========================================================================== }

procedure CursorShow();
begin
  Emit('?25h');
end;

procedure CursorHide();
begin
  Emit('?25l');
end;

procedure CursorSetStyle(AStyle: TCursorStyle);
begin
  Emit(IntToStr(Integer(AStyle)) + ' q');
end;

{ =========================================================================== }
{ Erase                                                                        }
{ =========================================================================== }

procedure EraseDisplay(AMode: TEraseDisplay);
begin
  Emit(IntToStr(Integer(AMode)) + 'J');
end;

procedure EraseLine(AMode: TEraseLine);
begin
  Emit(IntToStr(Integer(AMode)) + 'K');
end;

procedure EraseChars(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'X');
end;

{ =========================================================================== }
{ Scrolling                                                                    }
{ =========================================================================== }

procedure ScrollUp(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'S');
end;

procedure ScrollDown(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'T');
end;

procedure SetScrollRegion(ATop, ABottom: Integer);
begin
  Emit(IntToStr(ATop) + ';' + IntToStr(ABottom) + 'r');
end;

procedure ResetScrollRegion();
begin
  Emit('r');
end;

{ =========================================================================== }
{ Insert / delete                                                              }
{ =========================================================================== }

procedure InsertLines(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'L');
end;

procedure DeleteLines(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'M');
end;

procedure InsertChars(ACount: Integer);
begin
  Emit(IntToStr(ACount) + '@');
end;

procedure DeleteChars(ACount: Integer);
begin
  Emit(IntToStr(ACount) + 'P');
end;

{ =========================================================================== }
{ Alternate screen buffer                                                      }
{ =========================================================================== }

procedure AltScreenEnter();
begin
  Emit('?1049h');
end;

procedure AltScreenLeave();
begin
  Emit('?1049l');
end;

{ =========================================================================== }
{ Window title                                                                 }
{ =========================================================================== }

procedure SetWindowTitle(const ATitle: string);
begin
  { OSC 0 ; <title> BEL }
  Write(ESC + ']0;' + ATitle + #$0007);
end;

{ =========================================================================== }
{ Tab stops                                                                    }
{ =========================================================================== }

procedure TabSetHere();
begin
  Write(ESC + 'H');
end;

procedure TabClearHere();
begin
  Emit('0g');
end;

procedure TabClearAll();
begin
  Emit('3g');
end;

{ =========================================================================== }
{ Screen modes                                                                 }
{ =========================================================================== }

procedure ScreenSetReverse();
begin
  Emit('?5h');
end;

procedure ScreenResetReverse();
begin
  Emit('?5l');
end;

procedure WrapModeOn();
begin
  Emit('?7h');
end;

procedure WrapModeOff();
begin
  Emit('?7l');
end;

{ =========================================================================== }
{ Device status                                                                }
{ =========================================================================== }

procedure QueryCursorPosition();
begin
  Emit('6n');
end;

procedure QueryDeviceStatus();
begin
  Emit('5n');
end;

procedure QueryDeviceCode();
begin
  Emit('0c');
end;

{ =========================================================================== }
{ Terminal reset                                                               }
{ =========================================================================== }

procedure SoftReset();
begin
  Emit('!p');
end;

procedure HardReset();
begin
  Write(ESC + 'c');
end;

{ =========================================================================== }
{ Convenience                                                                  }
{ =========================================================================== }

procedure ClearScreen();
begin
  EraseDisplay(edAll);
  CursorHome();
end;

procedure ClearLine();
begin
  EraseLine(elAll);
end;

end.


