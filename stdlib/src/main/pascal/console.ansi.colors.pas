(******************************************************************************
 * Unit    : console.ansi.colors
 * Purpose : Chainable ANSI escape-code builder for terminal color and style
 *           output.  All methods return Self so calls can be chained
 *           fluently:
 *
 *             WriteLn(Ansi.Reset().Red().Bold().Text('Error!').ToString());
 *
 *           The global variable Ansi is created automatically at unit
 *           initialization.  Call Ansi.Reset() at the start of each chain
 *           to clear codes left over from the previous use.
 *
 * Author  : console.ansi contributors
 * Requires: SysUtils (IntToStr)
 ******************************************************************************)
unit console.ansi.colors;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  (**************************************************************************
   * TAnsiColor
   *
   * Builds an ANSI SGR (Select Graphic Rendition) escape sequence by
   * accumulating numeric codes and wrapping them around a text string.
   *
   * Typical usage:
   *   WriteLn(Ansi.Reset().Green().Underline().Text('OK').ToString());
   *
   * All color/style methods append one or more SGR codes to an internal
   * array and return Self, enabling method chaining.  Call Text() to
   * attach the string to be styled, then ToString() (or Print / PrintLn)
   * to obtain the final escaped output.
   **************************************************************************)
  TAnsiColor = class
  private
    (** Internal array of accumulated SGR parameter bytes. *)
    FCodes : array of Byte;

    (** The text string that will be wrapped in the escape sequence. *)
    FText  : string;

    (**************************************************************************
     * AddCode
     * @param ACode  A single SGR parameter byte to append to FCodes.
     * Grows the FCodes array by one and stores ACode at the new slot.
     **************************************************************************)
    procedure AddCode(ACode: Byte);

  public
    (**************************************************************************
     * Create
     * Initializes an empty builder with no codes and no text.
     **************************************************************************)
    constructor Create;

    (**************************************************************************
     * Destroy
     * Frees the builder.  The global Ansi instance is freed automatically
     * by the unit finalization block.
     **************************************************************************)
    destructor Destroy; override;

    { ======================================================================= }
    { Standard foreground colors  (SGR 30-37)                                 }
    { ======================================================================= }

    (** Sets the foreground color to black   (SGR 30). @return Self *)
    function Black        : TAnsiColor;
    (** Sets the foreground color to red     (SGR 31). @return Self *)
    function Red          : TAnsiColor;
    (** Sets the foreground color to green   (SGR 32). @return Self *)
    function Green        : TAnsiColor;
    (** Sets the foreground color to yellow  (SGR 33). @return Self *)
    function Yellow       : TAnsiColor;
    (** Sets the foreground color to blue    (SGR 34). @return Self *)
    function Blue         : TAnsiColor;
    (** Sets the foreground color to magenta (SGR 35). @return Self *)
    function Magenta      : TAnsiColor;
    (** Sets the foreground color to cyan    (SGR 36). @return Self *)
    function Cyan         : TAnsiColor;
    (** Sets the foreground color to white   (SGR 37). @return Self *)
    function White        : TAnsiColor;

    { ======================================================================= }
    { Bright foreground colors  (SGR 90-97)                                   }
    { ======================================================================= }

    (** Sets the foreground to bright black / dark grey (SGR 90). @return Self *)
    function BrightBlack  : TAnsiColor;
    (** Sets the foreground to bright red     (SGR 91). @return Self *)
    function BrightRed    : TAnsiColor;
    (** Sets the foreground to bright green   (SGR 92). @return Self *)
    function BrightGreen  : TAnsiColor;
    (** Sets the foreground to bright yellow  (SGR 93). @return Self *)
    function BrightYellow : TAnsiColor;
    (** Sets the foreground to bright blue    (SGR 94). @return Self *)
    function BrightBlue   : TAnsiColor;
    (** Sets the foreground to bright magenta (SGR 95). @return Self *)
    function BrightMagenta: TAnsiColor;
    (** Sets the foreground to bright cyan    (SGR 96). @return Self *)
    function BrightCyan   : TAnsiColor;
    (** Sets the foreground to bright white   (SGR 97). @return Self *)
    function BrightWhite  : TAnsiColor;

    { ======================================================================= }
    { Standard background colors  (SGR 40-47)                                 }
    { ======================================================================= }

    (** Sets the background color to black   (SGR 40). @return Self *)
    function BgBlack        : TAnsiColor;
    (** Sets the background color to red     (SGR 41). @return Self *)
    function BgRed          : TAnsiColor;
    (** Sets the background color to green   (SGR 42). @return Self *)
    function BgGreen        : TAnsiColor;
    (** Sets the background color to yellow  (SGR 43). @return Self *)
    function BgYellow       : TAnsiColor;
    (** Sets the background color to blue    (SGR 44). @return Self *)
    function BgBlue         : TAnsiColor;
    (** Sets the background color to magenta (SGR 45). @return Self *)
    function BgMagenta      : TAnsiColor;
    (** Sets the background color to cyan    (SGR 46). @return Self *)
    function BgCyan         : TAnsiColor;
    (** Sets the background color to white   (SGR 47). @return Self *)
    function BgWhite        : TAnsiColor;

    { ======================================================================= }
    { Bright background colors  (SGR 100-107)                                 }
    { ======================================================================= }

    (** Sets the background to bright black / dark grey (SGR 100). @return Self *)
    function BgBrightBlack  : TAnsiColor;
    (** Sets the background to bright red     (SGR 101). @return Self *)
    function BgBrightRed    : TAnsiColor;
    (** Sets the background to bright green   (SGR 102). @return Self *)
    function BgBrightGreen  : TAnsiColor;
    (** Sets the background to bright yellow  (SGR 103). @return Self *)
    function BgBrightYellow : TAnsiColor;
    (** Sets the background to bright blue    (SGR 104). @return Self *)
    function BgBrightBlue   : TAnsiColor;
    (** Sets the background to bright magenta (SGR 105). @return Self *)
    function BgBrightMagenta: TAnsiColor;
    (** Sets the background to bright cyan    (SGR 106). @return Self *)
    function BgBrightCyan   : TAnsiColor;
    (** Sets the background to bright white   (SGR 107). @return Self *)
    function BgBrightWhite  : TAnsiColor;

    { ======================================================================= }
    { Text attributes                                                          }
    { ======================================================================= }

    (** Applies bold / increased intensity (SGR 1). @return Self *)
    function Bold        : TAnsiColor;
    (** Applies dim / decreased intensity   (SGR 2). @return Self *)
    function Dim         : TAnsiColor;
    (** Applies italic style                (SGR 3). @return Self *)
    function Italic      : TAnsiColor;
    (** Applies underline                   (SGR 4). @return Self *)
    function Underline   : TAnsiColor;
    (** Applies slow blink                  (SGR 5). @return Self *)
    function Blink       : TAnsiColor;
    (** Swaps foreground and background colors (SGR 7). @return Self *)
    function Inverse     : TAnsiColor;
    (** Renders text invisible / concealed  (SGR 8). @return Self *)
    function Hidden      : TAnsiColor;
    (** Applies strikethrough / crossed out (SGR 9). @return Self *)
    function Strikethrough: TAnsiColor;

    { ======================================================================= }
    { 256-color palette  (SGR 38;5;n / 48;5;n)                               }
    { ======================================================================= }

    (**************************************************************************
     * Color256
     * Selects a foreground color from the 256-color palette.
     *   0-7   : standard colors (same as SGR 30-37)
     *   8-15  : high-intensity colors (same as SGR 90-97)
     *   16-231: 6x6x6 color cube
     *   232-255: greyscale ramp from dark to light
     * Emits ESC[38;5;<AIndex>m.
     * @param AIndex  Palette index in the range 0-255.
     * @return Self
     **************************************************************************)
    function Color256(AIndex: Byte)   : TAnsiColor;

    (**************************************************************************
     * BgColor256
     * Selects a background color from the 256-color palette.
     * Emits ESC[48;5;<AIndex>m.
     * @param AIndex  Palette index in the range 0-255.
     * @return Self
     **************************************************************************)
    function BgColor256(AIndex: Byte) : TAnsiColor;

    { ======================================================================= }
    { True-color / RGB  (SGR 38;2;r;g;b / 48;2;r;g;b)                        }
    { ======================================================================= }

    (**************************************************************************
     * ColorRGB
     * Selects an arbitrary foreground color using 24-bit true color.
     * Emits ESC[38;2;<R>;<G>;<B>m.
     * Requires a terminal with true-color support (e.g. most modern
     * xterm-256color or COLORTERM=truecolor terminals).
     * @param R  Red   channel (0-255).
     * @param G  Green channel (0-255).
     * @param B  Blue  channel (0-255).
     * @return Self
     **************************************************************************)
    function ColorRGB(R, G, B: Byte)  : TAnsiColor;

    (**************************************************************************
     * BgColorRGB
     * Selects an arbitrary background color using 24-bit true color.
     * Emits ESC[48;2;<R>;<G>;<B>m.
     * @param R  Red   channel (0-255).
     * @param G  Green channel (0-255).
     * @param B  Blue  channel (0-255).
     * @return Self
     **************************************************************************)
    function BgColorRGB(R, G, B: Byte): TAnsiColor;

    { ======================================================================= }
    { Output                                                                   }
    { ======================================================================= }

    (**************************************************************************
     * Text
     * Attaches the string that will be wrapped in the accumulated SGR codes
     * when ToString() is called.  Replaces any previously set text.
     * @param AText  The string to style.
     * @return Self
     **************************************************************************)
    function Text(const AText: string): TAnsiColor;

    (**************************************************************************
     * ToString
     * Builds and returns the final escape sequence:
     *   ESC [ <codes> m <text> ESC[0m
     * If no codes have been accumulated the plain text is returned as-is.
     * Does NOT clear the accumulated codes; call Reset() explicitly if
     * the instance is to be reused.
     * @return The styled string ready to pass to Write / WriteLn.
     **************************************************************************)
    function ToString(): string; override;

    (**************************************************************************
     * Print
     * Writes ToString() to stdout without a trailing newline.
     * Equivalent to: Write(Ansi.(...).ToString());
     **************************************************************************)
    procedure Print();

    (**************************************************************************
     * PrintLn
     * Writes ToString() to stdout followed by a newline.
     * Equivalent to: WriteLn(Ansi.(...).ToString());
     **************************************************************************)
    procedure PrintLn();

    (**************************************************************************
     * Reset
     * Clears all accumulated SGR codes and the stored text, returning the
     * builder to its initial empty state.  Should be called at the start
     * of every new chain when reusing the global Ansi instance.
     * @return Self
     **************************************************************************)
    function Reset(): TAnsiColor;
  end;

var
  (**************************************************************************
   * Ansi
   * Module-level singleton instance of TAnsiColor.  Created automatically
   * during unit initialization and freed during finalization.
   *
   * Because this is a shared instance, always begin a chain with Reset():
   *   WriteLn(Ansi.Reset().Red().Text('Error').ToString());
   **************************************************************************)
  Ansi: TAnsiColor;

const
  (** The SGR reset sequence appended after every styled string. *)
  ANSI_RESET = #$001B + '[0m';

implementation

{ --------------------------------------------------------------------------- }
{ TAnsiColor — private                                                         }
{ --------------------------------------------------------------------------- }

constructor TAnsiColor.Create;
begin
  inherited Create();
  SetLength(FCodes, 0);
  FText := '';
end;

destructor TAnsiColor.Destroy;
begin
  inherited Destroy();
end;

procedure TAnsiColor.AddCode(ACode: Byte);
var
  Len: Integer;
begin
  Len := Length(FCodes);
  SetLength(FCodes, Len + 1);
  FCodes[Len] := ACode;
end;

{ --------------------------------------------------------------------------- }
{ Standard foreground colors                                                   }
{ --------------------------------------------------------------------------- }

function TAnsiColor.Black        : TAnsiColor; begin AddCode(30); Result := Self; end;
function TAnsiColor.Red          : TAnsiColor; begin AddCode(31); Result := Self; end;
function TAnsiColor.Green        : TAnsiColor; begin AddCode(32); Result := Self; end;
function TAnsiColor.Yellow       : TAnsiColor; begin AddCode(33); Result := Self; end;
function TAnsiColor.Blue         : TAnsiColor; begin AddCode(34); Result := Self; end;
function TAnsiColor.Magenta      : TAnsiColor; begin AddCode(35); Result := Self; end;
function TAnsiColor.Cyan         : TAnsiColor; begin AddCode(36); Result := Self; end;
function TAnsiColor.White        : TAnsiColor; begin AddCode(37); Result := Self; end;

{ --------------------------------------------------------------------------- }
{ Bright foreground colors                                                     }
{ --------------------------------------------------------------------------- }

function TAnsiColor.BrightBlack  : TAnsiColor; begin AddCode(90); Result := Self; end;
function TAnsiColor.BrightRed    : TAnsiColor; begin AddCode(91); Result := Self; end;
function TAnsiColor.BrightGreen  : TAnsiColor; begin AddCode(92); Result := Self; end;
function TAnsiColor.BrightYellow : TAnsiColor; begin AddCode(93); Result := Self; end;
function TAnsiColor.BrightBlue   : TAnsiColor; begin AddCode(94); Result := Self; end;
function TAnsiColor.BrightMagenta: TAnsiColor; begin AddCode(95); Result := Self; end;
function TAnsiColor.BrightCyan   : TAnsiColor; begin AddCode(96); Result := Self; end;
function TAnsiColor.BrightWhite  : TAnsiColor; begin AddCode(97); Result := Self; end;

{ --------------------------------------------------------------------------- }
{ Standard background colors                                                   }
{ --------------------------------------------------------------------------- }

function TAnsiColor.BgBlack        : TAnsiColor; begin AddCode(40);  Result := Self; end;
function TAnsiColor.BgRed          : TAnsiColor; begin AddCode(41);  Result := Self; end;
function TAnsiColor.BgGreen        : TAnsiColor; begin AddCode(42);  Result := Self; end;
function TAnsiColor.BgYellow       : TAnsiColor; begin AddCode(43);  Result := Self; end;
function TAnsiColor.BgBlue         : TAnsiColor; begin AddCode(44);  Result := Self; end;
function TAnsiColor.BgMagenta      : TAnsiColor; begin AddCode(45);  Result := Self; end;
function TAnsiColor.BgCyan         : TAnsiColor; begin AddCode(46);  Result := Self; end;
function TAnsiColor.BgWhite        : TAnsiColor; begin AddCode(47);  Result := Self; end;

{ --------------------------------------------------------------------------- }
{ Bright background colors                                                     }
{ --------------------------------------------------------------------------- }

function TAnsiColor.BgBrightBlack  : TAnsiColor; begin AddCode(100); Result := Self; end;
function TAnsiColor.BgBrightRed    : TAnsiColor; begin AddCode(101); Result := Self; end;
function TAnsiColor.BgBrightGreen  : TAnsiColor; begin AddCode(102); Result := Self; end;
function TAnsiColor.BgBrightYellow : TAnsiColor; begin AddCode(103); Result := Self; end;
function TAnsiColor.BgBrightBlue   : TAnsiColor; begin AddCode(104); Result := Self; end;
function TAnsiColor.BgBrightMagenta: TAnsiColor; begin AddCode(105); Result := Self; end;
function TAnsiColor.BgBrightCyan   : TAnsiColor; begin AddCode(106); Result := Self; end;
function TAnsiColor.BgBrightWhite  : TAnsiColor; begin AddCode(107); Result := Self; end;

{ --------------------------------------------------------------------------- }
{ Text attributes                                                              }
{ --------------------------------------------------------------------------- }

function TAnsiColor.Bold         : TAnsiColor; begin AddCode(1); Result := Self; end;
function TAnsiColor.Dim          : TAnsiColor; begin AddCode(2); Result := Self; end;
function TAnsiColor.Italic       : TAnsiColor; begin AddCode(3); Result := Self; end;
function TAnsiColor.Underline    : TAnsiColor; begin AddCode(4); Result := Self; end;
function TAnsiColor.Blink        : TAnsiColor; begin AddCode(5); Result := Self; end;
function TAnsiColor.Inverse      : TAnsiColor; begin AddCode(7); Result := Self; end;
function TAnsiColor.Hidden       : TAnsiColor; begin AddCode(8); Result := Self; end;
function TAnsiColor.Strikethrough: TAnsiColor; begin AddCode(9); Result := Self; end;

{ --------------------------------------------------------------------------- }
{ 256-color palette                                                            }
{ --------------------------------------------------------------------------- }

function TAnsiColor.Color256(AIndex: Byte): TAnsiColor;
begin
  { Emits ESC[38;5;<AIndex>m }
  AddCode(38);
  AddCode(5);
  AddCode(AIndex);
  Result := Self;
end;

function TAnsiColor.BgColor256(AIndex: Byte): TAnsiColor;
begin
  { Emits ESC[48;5;<AIndex>m }
  AddCode(48);
  AddCode(5);
  AddCode(AIndex);
  Result := Self;
end;

{ --------------------------------------------------------------------------- }
{ True-color / RGB                                                             }
{ --------------------------------------------------------------------------- }

function TAnsiColor.ColorRGB(R, G, B: Byte): TAnsiColor;
begin
  { Emits ESC[38;2;<R>;<G>;<B>m }
  AddCode(38);
  AddCode(2);
  AddCode(R);
  AddCode(G);
  AddCode(B);
  Result := Self;
end;

function TAnsiColor.BgColorRGB(R, G, B: Byte): TAnsiColor;
begin
  { Emits ESC[48;2;<R>;<G>;<B>m }
  AddCode(48);
  AddCode(2);
  AddCode(R);
  AddCode(G);
  AddCode(B);
  Result := Self;
end;

{ --------------------------------------------------------------------------- }
{ Reset                                                                        }
{ --------------------------------------------------------------------------- }

function TAnsiColor.Reset(): TAnsiColor;
begin
  SetLength(FCodes, 0);
  FText := '';
  Result := Self;
end;

{ --------------------------------------------------------------------------- }
{ Text + output                                                                }
{ --------------------------------------------------------------------------- }

function TAnsiColor.Text(const AText: string): TAnsiColor;
begin
  FText  := AText;
  Result := Self;
end;

function TAnsiColor.ToString(): string;
var
  i     : Integer;
  Parts : string;
begin
  if Length(FCodes) = 0 then
  begin
    Result := FText;
    Exit;
  end;

  { Build the semicolon-separated SGR parameter string }
  Parts := '';
  for i := 0 to High(FCodes) do
  begin
    if i > 0 then Parts := Parts + ';';
    Parts := Parts + IntToStr(FCodes[i]);
  end;

  Result := #$001B + '[' + Parts + 'm' + FText + ANSI_RESET;
end;

procedure TAnsiColor.Print();
begin
  Write(ToString());
end;

procedure TAnsiColor.PrintLn();
begin
  WriteLn(ToString());
end;

{ --------------------------------------------------------------------------- }
{ Unit initialization / finalization                                           }
{ --------------------------------------------------------------------------- }

initialization
  Ansi := TAnsiColor.Create;

finalization
  Ansi.Free();

end.

