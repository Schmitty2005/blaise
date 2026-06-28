unit console.ansi.constants;

{**
 * Console.ANSI.Constants
 *
 * Defines ANSI escape code constants for use in console/terminal applications.
 *
 * Usage example:
 *   WriteLn(ANSI_FG_RED + 'Error: something went wrong.' + ANSI_RESET);
 *   WriteLn(ANSI_BOLD + ANSI_FG_BRIGHT_GREEN + 'Success!' + ANSI_RESET);
 *
 * All sequences begin with the ESC character (#$001B) followed by '[' (CSI).
 *}

{$mode objfpc}{$H+}

interface

const

  { ======================================================================
    Control Characters
    ====================================================================== }

  /// NULL
  ANSI_NUL         = #$0000;

  /// Bell  (BEL)
  ANSI_BELL        = #$0007;

  /// Backspace  (BS)
  ANSI_BACKSPACE   = #$0008;

  /// Horizontal Tab  (HT)
  ANSI_TAB         = #$0009;

  /// Line Feed  (LF)
  ANSI_LF          = #$000A;

  /// Vertical Tab  (VT)
  ANSI_VT          = #$000B;

  /// Form Feed  (FF)
  ANSI_FF          = #$000C;

  /// Carriage Return  (CR)
  ANSI_CR          = #$000D;

  /// Escape  (ESC)
  ANSI_ESC         = #$001B;

  /// Delete  (DEL)
  ANSI_DEL         = #$007F;

  /// Control Sequence Introducer  ESC + '['
  ANSI_CSI         = #$001B'[';

  /// Operating System Command prefix  ESC + ']'
  ANSI_OSC         = #$001B']';

  { ======================================================================
    Reset / General Attributes
    ====================================================================== }

  /// Reset all attributes (color, bold, etc.) to default
  ANSI_RESET              = #$001B'[0m';

  /// Reset — alias for ANSI_RESET
  ANSI_ATTR_RESET         = #$001B'[0m';

  { ======================================================================
    Text Style / Decoration Attributes
    ====================================================================== }

  ANSI_BOLD               = #$001B'[1m';
  ANSI_DIM                = #$001B'[2m';   // Faint / decreased intensity
  ANSI_ITALIC             = #$001B'[3m';   // Not widely supported
  ANSI_UNDERLINE          = #$001B'[4m';
  ANSI_BLINK_SLOW         = #$001B'[5m';   // < 150 blinks per minute
  ANSI_BLINK_RAPID        = #$001B'[6m';   // > 150 blinks per minute (rarely supported)
  ANSI_REVERSE_VIDEO      = #$001B'[7m';   // Swap foreground and background
  ANSI_CONCEAL            = #$001B'[8m';   // Hidden (not widely supported)
  ANSI_STRIKETHROUGH      = #$001B'[9m';   // Crossed-out text

  /// Double underline (rarely supported)
  ANSI_DOUBLE_UNDERLINE   = #$001B'[21m';

  /// Turn off bold / dim
  ANSI_BOLD_OFF           = #$001B'[22m';
  ANSI_ITALIC_OFF         = #$001B'[23m';
  ANSI_UNDERLINE_OFF      = #$001B'[24m';
  ANSI_BLINK_OFF          = #$001B'[25m';
  ANSI_REVERSE_OFF        = #$001B'[27m';
  ANSI_CONCEAL_OFF        = #$001B'[28m';
  ANSI_STRIKETHROUGH_OFF  = #$001B'[29m';

  /// Overline (rarely supported)
  ANSI_OVERLINE           = #$001B'[53m';
  ANSI_OVERLINE_OFF       = #$001B'[55m';

  { ======================================================================
    Standard Foreground Colors  (30-37)
    ====================================================================== }

  ANSI_FG_BLACK           = #$001B'[30m';
  ANSI_FG_RED             = #$001B'[31m';
  ANSI_FG_GREEN           = #$001B'[32m';
  ANSI_FG_YELLOW          = #$001B'[33m';
  ANSI_FG_BLUE            = #$001B'[34m';
  ANSI_FG_MAGENTA         = #$001B'[35m';
  ANSI_FG_CYAN            = #$001B'[36m';
  ANSI_FG_WHITE           = #$001B'[37m';

  /// Reset foreground to default terminal color
  ANSI_FG_DEFAULT         = #$001B'[39m';

  { ======================================================================
    Standard Background Colors  (40-47)
    ====================================================================== }

  ANSI_BG_BLACK           = #$001B'[40m';
  ANSI_BG_RED             = #$001B'[41m';
  ANSI_BG_GREEN           = #$001B'[42m';
  ANSI_BG_YELLOW          = #$001B'[43m';
  ANSI_BG_BLUE            = #$001B'[44m';
  ANSI_BG_MAGENTA         = #$001B'[45m';
  ANSI_BG_CYAN            = #$001B'[46m';
  ANSI_BG_WHITE           = #$001B'[47m';

  /// Reset background to default terminal color
  ANSI_BG_DEFAULT         = #$001B'[49m';

  { ======================================================================
    Bright / High-Intensity Foreground Colors  (90-97)
    ====================================================================== }

  ANSI_FG_BRIGHT_BLACK    = #$001B'[90m';   // Often rendered as dark grey
  ANSI_FG_BRIGHT_RED      = #$001B'[91m';
  ANSI_FG_BRIGHT_GREEN    = #$001B'[92m';
  ANSI_FG_BRIGHT_YELLOW   = #$001B'[93m';
  ANSI_FG_BRIGHT_BLUE     = #$001B'[94m';
  ANSI_FG_BRIGHT_MAGENTA  = #$001B'[95m';
  ANSI_FG_BRIGHT_CYAN     = #$001B'[96m';
  ANSI_FG_BRIGHT_WHITE    = #$001B'[97m';

  // Convenient aliases
  ANSI_FG_DARK_GREY       = #$001B'[90m';
  ANSI_FG_GREY            = #$001B'[37m';
  ANSI_FG_LIGHT_GREY      = #$001B'[97m';

  { ======================================================================
    Bright / High-Intensity Background Colors  (100-107)
    ====================================================================== }

  ANSI_BG_BRIGHT_BLACK    = #$001B'[100m';  // Often rendered as dark grey
  ANSI_BG_BRIGHT_RED      = #$001B'[101m';
  ANSI_BG_BRIGHT_GREEN    = #$001B'[102m';
  ANSI_BG_BRIGHT_YELLOW   = #$001B'[103m';
  ANSI_BG_BRIGHT_BLUE     = #$001B'[104m';
  ANSI_BG_BRIGHT_MAGENTA  = #$001B'[105m';
  ANSI_BG_BRIGHT_CYAN     = #$001B'[106m';
  ANSI_BG_BRIGHT_WHITE    = #$001B'[107m';

  ANSI_BG_DARK_GREY       = #$001B'[100m';

  { ======================================================================
    Cursor Movement
    ====================================================================== }

  /// Move cursor up 1 line
  ANSI_CURSOR_UP          = #$001B'[A';
  /// Move cursor down 1 line
  ANSI_CURSOR_DOWN        = #$001B'[B';
  /// Move cursor right 1 column
  ANSI_CURSOR_RIGHT       = #$001B'[C';
  /// Move cursor left 1 column
  ANSI_CURSOR_LEFT        = #$001B'[D';

  /// Move to beginning of next line
  ANSI_CURSOR_NEXT_LINE   = #$001B'[E';
  /// Move to beginning of previous line
  ANSI_CURSOR_PREV_LINE   = #$001B'[F';

  /// Move cursor to column 1 of current row
  ANSI_CURSOR_COL1        = #$001B'[G';

  /// Move cursor to home position (row 1, col 1)
  ANSI_CURSOR_HOME        = #$001B'[H';

  /// Save cursor position (ANSI / VT100)
  ANSI_CURSOR_SAVE        = #$001B'[s';
  /// Restore cursor position (ANSI / VT100)
  ANSI_CURSOR_RESTORE     = #$001B'[u';

  /// Save cursor position (DEC / xterm)
  ANSI_CURSOR_SAVE_DEC    = #$001B'7';
  /// Restore cursor position (DEC / xterm)
  ANSI_CURSOR_RESTORE_DEC = #$001B'8';

  /// Hide cursor
  ANSI_CURSOR_HIDE        = #$001B'[?25l';
  /// Show cursor
  ANSI_CURSOR_SHOW        = #$001B'[?25h';

  /// Request cursor position report  (terminal responds with ESC[<row>;<col>R)
  ANSI_CURSOR_REPORT      = #$001B'[6n';

  { ======================================================================
    Erase / Clear Sequences
    ====================================================================== }

  /// Erase from cursor to end of screen
  ANSI_ERASE_SCREEN_END   = #$001B'[0J';
  /// Erase from cursor to beginning of screen
  ANSI_ERASE_SCREEN_BEGIN = #$001B'[1J';
  /// Erase entire screen (cursor position unchanged)
  ANSI_ERASE_SCREEN       = #$001B'[2J';
  /// Erase entire screen and delete scrollback buffer
  ANSI_ERASE_SCREEN_ALL   = #$001B'[3J';

  /// Erase from cursor to end of line
  ANSI_ERASE_LINE_END     = #$001B'[0K';
  /// Erase from cursor to beginning of line
  ANSI_ERASE_LINE_BEGIN   = #$001B'[1K';
  /// Erase entire current line
  ANSI_ERASE_LINE         = #$001B'[2K';

  { ======================================================================
    Scrolling
    ====================================================================== }

  /// Scroll screen up by 1 line
  ANSI_SCROLL_UP          = #$001B'[S';
  /// Scroll screen down by 1 line
  ANSI_SCROLL_DOWN        = #$001B'[T';

  { ======================================================================
    Screen / Buffer Modes
    ====================================================================== }

  /// Switch to alternate screen buffer
  ANSI_SCREEN_ALT_ON      = #$001B'[?1049h';
  /// Switch back to normal screen buffer
  ANSI_SCREEN_ALT_OFF     = #$001B'[?1049l';

  { ======================================================================
    256-Color Sequence Prefixes
    Note: append IntToStr(n) + 'm' to complete the sequence.

    Foreground:  ESC[38;5;<n>m   where <n> is 0..255
    Background:  ESC[48;5;<n>m   where <n> is 0..255

    Standard 16 colors   : 0-15
    216 color cube        : 16-231
    Grayscale ramp        : 232-255
    ====================================================================== }

  ANSI_FG_256_PREFIX      = #$001B'[38;5;';   // Append: IntToStr(n) + 'm'
  ANSI_BG_256_PREFIX      = #$001B'[48;5;';   // Append: IntToStr(n) + 'm'

  { ======================================================================
    24-Bit (True Color / RGB) Sequence Prefixes
    Note: append IntToStr(R)+';'+IntToStr(G)+';'+IntToStr(B)+'m'

    Foreground:  ESC[38;2;<r>;<g>;<b>m
    Background:  ESC[48;2;<r>;<g>;<b>m
    ====================================================================== }

  ANSI_FG_RGB_PREFIX      = #$001B'[38;2;';   // Append: '<r>;<g>;<b>m'
  ANSI_BG_RGB_PREFIX      = #$001B'[48;2;';   // Append: '<r>;<g>;<b>m'

  { ======================================================================
    Hyperlink Sequences  (OSC 8 - supported by some modern terminals)
    ====================================================================== }

  /// Open hyperlink — append URL then #$0007, then link text, then ANSI_LINK_CLOSE
  ANSI_LINK_OPEN          = #$001B']8;;';
  ANSI_LINK_CLOSE         = #$001B']8;;'#$0007;

  { ======================================================================
    Window Title  (OSC 2)
    ====================================================================== }

  /// Set window title — append title string then ANSI_TITLE_SUFFIX
  ANSI_TITLE_PREFIX       = #$001B']2;';
  ANSI_TITLE_SUFFIX       = #$0007;

  { ======================================================================
    256-Color Palette Index Constants  (named entries)
    ====================================================================== }

  // Standard 16 color indices  (exact appearance is terminal-defined)
  ANSI_IDX_BLACK          =   0;
  ANSI_IDX_MAROON         =   1;
  ANSI_IDX_GREEN          =   2;
  ANSI_IDX_OLIVE          =   3;
  ANSI_IDX_NAVY           =   4;
  ANSI_IDX_PURPLE         =   5;
  ANSI_IDX_TEAL           =   6;
  ANSI_IDX_SILVER         =   7;
  ANSI_IDX_GREY           =   8;
  ANSI_IDX_RED            =   9;
  ANSI_IDX_LIME           =  10;
  ANSI_IDX_YELLOW         =  11;
  ANSI_IDX_BLUE           =  12;
  ANSI_IDX_FUCHSIA        =  13;
  ANSI_IDX_AQUA           =  14;
  ANSI_IDX_WHITE          =  15;

  // Greyscale ramp (indices 232-255, near-black to near-white)
  ANSI_IDX_GREY_0         = 232;
  ANSI_IDX_GREY_1         = 233;
  ANSI_IDX_GREY_2         = 234;
  ANSI_IDX_GREY_3         = 235;
  ANSI_IDX_GREY_4         = 236;
  ANSI_IDX_GREY_5         = 237;
  ANSI_IDX_GREY_6         = 238;
  ANSI_IDX_GREY_7         = 239;
  ANSI_IDX_GREY_8         = 240;
  ANSI_IDX_GREY_9         = 241;
  ANSI_IDX_GREY_10        = 242;
  ANSI_IDX_GREY_11        = 243;
  ANSI_IDX_GREY_12        = 244;
  ANSI_IDX_GREY_13        = 245;
  ANSI_IDX_GREY_14        = 246;
  ANSI_IDX_GREY_15        = 247;
  ANSI_IDX_GREY_16        = 248;
  ANSI_IDX_GREY_17        = 249;
  ANSI_IDX_GREY_18        = 250;
  ANSI_IDX_GREY_19        = 251;
  ANSI_IDX_GREY_20        = 252;
  ANSI_IDX_GREY_21        = 253;
  ANSI_IDX_GREY_22        = 254;
  ANSI_IDX_GREY_23        = 255;

{ ============================================================================
  Helper functions
  ============================================================================ }

/// Build a foreground 256-color sequence for palette index n (0..255)
function AnsiFg256(const n: Byte): string;

/// Build a background 256-color sequence for palette index n (0..255)
function AnsiBg256(const n: Byte): string;

/// Build a true-color (24-bit) foreground sequence
function AnsiFgRGB(const R, G, B: Byte): string;

/// Build a true-color (24-bit) background sequence
function AnsiBgRGB(const R, G, B: Byte): string;

/// Move cursor to absolute position (1-based row and column)
function AnsiCursorPos(const Row, Col: Word): string;

/// Move cursor up N lines
function AnsiCursorUp(const N: Word): string;

/// Move cursor down N lines
function AnsiCursorDown(const N: Word): string;

/// Move cursor right N columns
function AnsiCursorRight(const N: Word): string;

/// Move cursor left N columns
function AnsiCursorLeft(const N: Word): string;

/// Wrap text in a foreground color, resetting afterward
function AnsiColorFg(const Text, FgCode: string): string;

/// Wrap text in foreground + background colors, resetting afterward
function AnsiColor(const Text, FgCode, BgCode: string): string;

/// Set terminal window title (OSC 2)
function AnsiSetTitle(const Title: string): string;

implementation

function AnsiFg256(const n: Byte): string;
begin
  Result := ANSI_FG_256_PREFIX + IntToStr(n) + 'm';
end;

function AnsiBg256(const n: Byte): string;
begin
  Result := ANSI_BG_256_PREFIX + IntToStr(n) + 'm';
end;

function AnsiFgRGB(const R, G, B: Byte): string;
begin
  Result := ANSI_FG_RGB_PREFIX + IntToStr(R) + ';' + IntToStr(G) + ';' + IntToStr(B) + 'm';
end;

function AnsiBgRGB(const R, G, B: Byte): string;
begin
  Result := ANSI_BG_RGB_PREFIX + IntToStr(R) + ';' + IntToStr(G) + ';' + IntToStr(B) + 'm';
end;

function AnsiCursorPos(const Row, Col: Word): string;
begin
  Result := ANSI_CSI + IntToStr(Row) + ';' + IntToStr(Col) + 'H';
end;

function AnsiCursorUp(const N: Word): string;
begin
  Result := ANSI_CSI + IntToStr(N) + 'A';
end;

function AnsiCursorDown(const N: Word): string;
begin
  Result := ANSI_CSI + IntToStr(N) + 'B';
end;

function AnsiCursorRight(const N: Word): string;
begin
  Result := ANSI_CSI + IntToStr(N) + 'C';
end;

function AnsiCursorLeft(const N: Word): string;
begin
  Result := ANSI_CSI + IntToStr(N) + 'D';
end;

function AnsiColorFg(const Text, FgCode: string): string;
begin
  Result := FgCode + Text + ANSI_RESET;
end;

function AnsiColor(const Text, FgCode, BgCode: string): string;
begin
  Result := FgCode + BgCode + Text + ANSI_RESET;
end;

function AnsiSetTitle(const Title: string): string;
begin
  Result := ANSI_TITLE_PREFIX + Title + ANSI_TITLE_SUFFIX;
end;

end.