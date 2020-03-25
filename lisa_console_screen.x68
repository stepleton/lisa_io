* # Apple Lisa I/O library: fixed-width text drawing routines.
*
* Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.
*
*
* ## Introduction
*
* This file contains macros and procedures for drawing fixed-width text to the
* Lisa's bitmap display. The procedures supply some basic functions
* (initialisation, clearing the screen), whilst the `mFont8` macro (the only
* "public" macro defined by this library) generates text-display library code
* customised for bitmap font data that you supply.
*
* For now, this library can only draw text with glyphs that are eight pixels
* wide. These glyphs can be any height. Rows of text may be separated by any
* number of pixels. As such, a screenful of text may be varying numbers of
* rows tall, depending on specifics of the font, but will always be exactly 90
* columns wide.
*
* Neither the existing procedures nor the generated code are designed to be
* relocatable---once included or generated, the code expects itself (and a
* small amount of internal state) to remain in the same memory locations.
*
*
* ## Usage
*
* This library is written in the dialect of 68000 macro assembly supported by
* the open-source Windows-only EASy68k development environment and simulator
* (http://www.easy68k.com/). Converting the library's source code to a dialect
* compatible with other popular assemblers may require some recoding of its
* numerous macros.
*
* There is a standalone version of the EASy68k assembler that is usable from a
* Unix command line (https://github.com/rayarachelian/EASy68K-asm). All
* development work on the library used this assembler, and users who don't want
* to use a different assembly dialect are recommended to use it themselves.
*
* To use this library in your own project, the first step is to define two
* symbols that refer to sections of your assembled program:
*
*    - `kSecCode`: a section containing executable code
*    - `kSecScratch`: a section containing mutable, temporary data
*
* Next, you can include the library in the conventional way:
*
*    INCLUDE lisa_console_screen.x68  ; Screen text drawing library
*
* The fixed procedures in this library are:
*
*    - `InitLisaConsoleScreen`: Prepare this library's global data structures
*    - `ClearLisaConsoleScreen`: Blank the entire display
*
* Additionally, the `mFont8` macro will create procedures like these (subsitute
* "MyFont" with the name of the font you've passed to `mFont8`):
*
*    - `PutcMyFont`: Draw a glyph at a specified column and row
*    - `GotoXYMyFont`: Set the screen position for the next `PrintMyFont` call
*    - `ScrollMyFont`: Scroll the entire display up one line
*    - `PrintMyFont`: Print a null-terminated string of 8-bit characters
*
* These procedures (or procedure templates) are individually documented at the
* sites of their definition below. Overall usage is straightforward; just
* remember to call `InitLisaConsoleScreen` prior to invoking any other fixed
* or generated procedure from this library.
*
* The library defines an additional symbol, `zLisaConsoleScreenBase`. After
* calling `InitLisaConsoleScreen`, this symbol will refer to a memory location
* whose four-byte value is the address of the start of video memory. You can
* alter this pointer value if you'd like to write text to other 720-pixel-wide
* portions of RAM for some reason.
*
*
* ## Invoking the `mFont8` macro
*
* `mFont8` expects a "font name" first argument, which it uses to construct the
* names of two symbols (substitite "MyFont" with the value of the argument):
*
*    - `kFontMyFontGlyphCols`: `mFont8` checks that this symbol is equal to 8
*    - `fontMyFont`: the memory address of the font bitmap data
*
* The two other arguments to `mFont8`, both relating to the "tallness" of your
* font, are described above the macro's definition.
*
* For more information on the bitmap data format, read the "Font data from you"
* section below.
*
* Even though `mFont8` must be invoked for every separate bitmap font you wish
* to use, the macro (and each macro it calls) reuses lots of code for common
* functions, so there is not much overhead to generating display code for two
* fonts with the same size and vertical spacing. In order to implement this
* reuse, `mFont8` depends on "guard variables" to control the macro expansion:
* you may need to define additional guard variables if your font has a novel
* shape (width, height, and vertical spacing). It's easy to do; search for
* "GUARDS" below for instructions.
*
*
* ## Font data from you
*
* Font data for the `mFont8` macro is a contiguous array of 256 character
* bitmaps, with each bitmap's bytes ordered from top to bottom.
*
* For best results, the bitmaps should be black-on-white lettering, where `1`
* bits are black. When spacing adjacent rows of text with empty rows of pixels,
* the `mFont8`-generated code uses white `0` pixels.
*
* Here are some example glyphs from the included "Lisa_Console" font
* (`font_Lisa_Console.x68`):
*
*            .....#..   $04            ......#.   $02
*            ........   $00            ......#.   $02
*            ....##..   $0C            ......#.   $02
*            .....#..   $04            ......#.   $02
*            .....#..   $04            #.....#.   $82
*            .....#..   $04            .#...#..   $44
*            .....#..   $04            ..###...   $38
*            #....#..   $84            ........   $00
*            .####...   $78            ........   $00
*
* The Python script `bdf_to_lisa_console_screen_x68.py` is a (quickly-written,
* surely buggy) tool for converting eight-pixel-wide fixed-width BDF bitmap
* font files (https://en.wikipedia.org/wiki/Glyph_Bitmap_Distribution_Format)
* to the bitmap format used by the `mFont8` macro. Graphical bitmap font
* editors like `gbdfed` (http://sofia.nmsu.edu/~mleisher/Software/gbdfed/)
* and `fony` (http://hukka.ncn.fi/?fony) may be useful for designing new fonts.
*
*
* ## The library's operating requirements
*
* The library assumes that the Lisa's MMU setup and the contents of its first
* $800 bytes of RAM are both in the configurations that the Lisa's boot ROM
* leaves them in after handing control over to user code. These assumptions
* allow `InitLisaConsoleScreen` to identify the start of video memory; if they
* do not hold, you can place the video memory base address into
* `zLisaConsoleScreenBase` yourself.
*
* Additionally, the library assumes that hard-coded references to font data and
* global state in memory will not need to change throughout the full runtime
* of the program.
*
*
* ## Resources
*
* The following resources were used to develop this library:
*
*    - EASy68k-asm: standalone version of the EASy68k assembler
*      https://github.com/rayarachelian/EASy68K-asm
*    - lisaem: Apple Lisa emulator
*      https://lisaem.sunder.net/
*    - Lisa_Boot_ROM_Asm_Listing.TEXT: Authoritative info for boot ROM ver. H.
*      http://bitsavers.org/pdf/apple/lisa/firmware/Lisa_Boot_ROM_Asm_Listing.TEXT
*
*
* ## Acknowledgements
*
* As with so many of my Lisa hobby software development efforts, the excellent
* technical resources furnished by Ray Arachelian and by bitsavers.org are
* gratefully acknowledged.
*
*
* ## Revision history
*
* This section records the development of this file as part of the `lisa_io`
* library at <http://github.com/stepleton/lisa_io>.
*
*    - 15 March 2020: Initial release.
*      (Tom Stepleton, stepleton@gmail.com, London)


**** GUARDS for making certain that shared code generation occurs exactly once
* These guard variables prevent code that is shared for specific font metrics
* from being defined twice, much like header guards in C/C++ .h files. If you
* are trying to use a font with a metric that doesn't have a guard variable
* defined here, all you need to do is define a new one in the same pattern
* seen here. For _mFGrdAxBxC, A is the glyph width, B is the amount of
* above-glyph vertical padding, and C is the glyph height, all units pixels.

_mFGrd8x1x9 SET 0                    ; 8px wide, 1px vpad, 9px height


**** MACROS of general utility


    ; _mLcsIDis -- Disable interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Uses a word of stack space; moves the stack pointer
_mLcsIDis   MACRO
      MOVE.W  SR,-(SP)
      ORI.W   #$0700,SR
            ENDM

    ; _mLcsIEna -- Enable interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Frees a word of stack space; moves the stack pointer
_mLcsIEna   MACRO
      MOVE.W  (SP)+,SR
            ENDM


**** MACROS for generating code shared by fonts with the same metrics.


    ; _mVPad8 -- Conditional insertion of a row of above-glyph vertical padding
    ; Args:
    ;   \1: How many rows of above-glyph vertical padding this glyph has
    ;   \2: Which row of padding this would be, counting up from 0
    ;   \3: Address register pointing to a byte on the screen
    ;   \4: Register containing $5A (the number of bytes in a screen row)
    ; Notes:
    ;   Only generates code if \1 > \2
    ;   If it does, the code will advance register \3 by $5A bytes
_mVPad8     MACRO
              IFGT (\1-\2)
      CLR.B   (\3)                   ; Clear row of the on-screen glyph copy
      ADDA.W  \4,\3                  ; Advance to the next row
              ENDC
            ENDM


    ; _mGRow8 -- Conditional copying of a row of glyph data to the screen
    ; Args:
    ;   \1: How many pixel rows this glyph has
    ;   \2: Which row of the glyph this would be, counting up from 0
    ;   \3; Address register pointing to the \2th row of the glyph
    ;   \4: Address register pointing to a byte on the screen
    ;   \5: Register containing $5A (the number of bytes in a screen row)
    ; Notes:
    ;   Only generates code if \1 > \2
    ;   If it does, the code will increment \3 and advance \4 by $5A bytes
_mGRow8     MACRO
              IFGT (\1-\2)
      MOVE.B  (\3)+,(\4)             ; Copy next row of the glyph
      ADDA.W  \5,\4                  ; Advance to the next row on screen
              ENDC
            ENDM


    ; _mFont8 -- Create shared routines for similarly-sized 8px-wide fonts
    ;   \1: How many rows of above-glyph vertical padding this font has
    ;   \2: How many rows glyphs in this font have
    ; Notes:
    ;   Uses a guard system to ensure code is generated only once
    ;   Code following the macro invocation will be in kSecCode
_mFont8     MACRO
              IFEQ (_mFGrd8x\1x\2)   ; MULTIPLE RUN GUARD BEGIN
_mFGrd8x\1x\2 SET 1

      ; Define certain constants that the code will use.
_kRows8x\1x\2 EQU (364/(\1+\2))      ; # of rows of this font that fit on screen
_kRDel8x\1x\2 EQU (90*(\1+\2))       ; Memory interval between text rows


      SECTION kSecCode

      ; _Putc8x\1x\2 -- Draw a glyph at a specified column and row
      ; Args:
      ;   D0: (word) Glyph to draw---note that this is a word!
      ;   D1: (word) Column receiving the character
      ;   D2: (word) Row receiving the character
      ;   A0: Address of the font glyph data
      ; Notes:
      ;   Trashes A0-A1/D0,D2
_Putc8x\1x\2:
      MULU.W  #\2,D0                 ; Compute offset to our glyph in our font
      ADDA.L  D0,A0                  ; Add to obtain the glyph address

      ; Check col/row are both in bounds
      CMPI.W  #$5A,D1                ; Compare column to number of columns
      BHS.S   .rt\@                  ; Out-of-bounds, give up
      CMPI.W  #_kRows8x\1x\2,D2      ; Compare row to number of rows
      BHS.S   .rt\@                  ; Out-of-bounds, give up

      ; Compute screen address receiving the glyph
      MOVEA.L zLisaConsoleScreenBase,A1  ; Load video memory base address
      MULU.W  #_kRDel8x\1x\2,D2      ; First pixel row offset from screen top
      ADD.W   D1,D2                  ; Offset to first byte receiving glyph
      ADDA.W  D2,A1                  ; Address of first byte receiving glyph

      ; Load number of bytes in a screen row into D0
      MOVE.W  #$5A,D0                ; That's ninety bytes

      ; Add vertical padding above the glyph using an unrolled loop
      _mVPad8 \1,0,A1,D0
      _mVPad8 \1,1,A1,D0
      _mVPad8 \1,2,A1,D0
      _mVPad8 \1,3,A1,D0
      _mVPad8 \1,4,A1,D0
      _mVPad8 \1,5,A1,D0
      _mVPad8 \1,6,A1,D0
              IFGT (\1-8)
      FAIL The mFont8 macro does not support padding beyond eight rows
              ENDC

      ; Now copy the glyph data itself to the screen with an unrolled loop
      _mGRow8 \2,0,A0,A1,D0
      _mGRow8 \2,1,A0,A1,D0
      _mGRow8 \2,2,A0,A1,D0
      _mGRow8 \2,3,A0,A1,D0
      _mGRow8 \2,4,A0,A1,D0
      _mGRow8 \2,5,A0,A1,D0
      _mGRow8 \2,6,A0,A1,D0
      _mGRow8 \2,7,A0,A1,D0
      _mGRow8 \2,8,A0,A1,D0
      _mGRow8 \2,9,A0,A1,D0
      _mGRow8 \2,10,A0,A1,D0
      _mGRow8 \2,11,A0,A1,D0
      _mGRow8 \2,12,A0,A1,D0
      _mGRow8 \2,13,A0,A1,D0
      _mGRow8 \2,14,A0,A1,D0
      _mGRow8 \2,15,A0,A1,D0
              IFGT (\2-16)
      FAIL The mFont8 macro does not support glyphs taller than 16 rows
              ENDC

.rt\@ RTS                            ; Back to caller

      ; Scroll\1 -- Scroll the entire display up one line
      ; Args:
      ;   (none)
      ; Notes:
      ;   Consumes six words of stack storage
_Scroll8x\1x\2:
      MOVEM.L D0/A0-A1,-(SP)         ; Save registers we use
      MOVEA.L zLisaConsoleScreenBase,A0  ; Copy screen base address into A0...
      MOVEA.L A0,A1                  ; ...and A1, then add to A1 the memory...
      ADD.L   #_kRDel8x\1x\2,A1      ; ...gap between successive character rows
      MOVE.W  #((45*(_kRows8x\1x\2-1)*(\1+\2))-1),D0   ; How many words to copy?
.lm\@ MOVE.W  (A1)+,(A0)+            ; Copy data from next text row to this one
      DBRA    D0,.lm\@               ; Loop until all words are copied
      MOVE.W  #((_kRDel8x\1x\2/2)-1),D0  ; For clearing the bottom screen row
.lc\@ CLR.W   (A0)+                  ; Clear data
      DBRA    D0,.lc\@               ; Loop until whole bottom row is clear
      SUBQ.W  #1,zRow\1x\2           ; Decrement cursor position row
      MOVEM.L (SP)+,D0/A0-A1         ; Restore registers we used
      RTS                            ; Back to the caller

      ; _Print8x\1x\2 -- Print a null-terminated 8-bit char string to the screen
      ; Args:
      ;   A2: Address of the null-terminated string to print
      ;   A3: Address of the font glyph data
      ; Notes:
      ;   Wraps text that overflows a line to the following line
      ;   Scrolls the display upward if the cursor falls below the "bottom"
      ;   Printing to the bottom-left row/col will therefore cause scrolling
      ;   Newline chars ($0A) move the cursor in the usual UNIX way
      ;   All other chars except $00 display a glyph to the display
      ;   Suspends all interrupts while printing
      ;   Trashes A0-A3/D0-D2
_Print8x\1x\2:
      _mLcsIDis                      ; Disable interrupts for speed

.tp\@ CLR.W   D0                     ; So that D0 will only contain the byte...
      MOVE.B  (A2)+,D0               ; ...that we move into it here
      BEQ.S   .rt\@                  ; At the null terminator? Quit

      CMPI.B  #$0A,D0                ; Is this a newline?
      BEQ.S   .nl\@                  ; Yes, skip ahead to do a newline

      MOVE.W  zCol\1x\2,D1           ; Copy current column
      MOVE.W  zRow\1x\2,D2           ; Copy current row
      MOVEA.L A3,A0                  ; Restore saved font address to A0
      BSR     _Putc8x\1x\2           ; Print the character in D0

      ADDQ.W  #1,D1                  ; Compute next column
      CMPI.W  #$5A,D1                ; Compare next column to number of columns
      BLO.S   .sc\@                  ; Still in bounds? Skip to column-saving

.nl\@ CLR.W   zCol\1x\2              ; Not in bounds; return to column 0...
      MOVE.W  zRow\1x\2,D2           ; ...copy current row again
      ADDQ.W  #1,D2                  ; ...increment it
      MOVE.W  D2,zRow\1x\2           ; ...and save it again
      CMPI.W  #_kRows8x\1x\2,D2      ; Is current row on the screen?
      BLO.S   .tp\@                  ;   Yes, on to the next character
      BSR     _Scroll8x\1x\2         ;   No, scroll one row up first...
      BRA.S   .tp\@                  ;   ...and then on to the next character

.sc\@ MOVE.W  D1,zCol\1x\2           ; In bounds; save the incremented column
      BRA.S   .tp\@                  ; On to the next character

.rt\@ _mLcsIEna                      ; Re-enable interrupts
      RTS                            ; Back to caller


      ; State for writing full strings.
      SECTION kSecScratch

      DS.W    0                      ; Enforce word alignment
zCol\1x\2:
      DC.W    $0000                  ; Column receiving the next character
zRow\1x\2:
      DC.W    $0000                  ; Row receiving the next character


      ; Return to the code section when exiting the macro.
      SECTION kSecCode


              ENDC                   ; MULTIPLE RUN GUARD END
            ENDM


**** MACRO for generating code for individual fonts


    ; mFont8 -- Create drawing routines for a font with 8-pixel-wide glyphs
    ; Args:
    ;   \1: Font name -- used to construct the names of required constants
    ;   \2: How many rows of above-glyph vertical padding this font has
    ;   \3: How many rows glyphs in this font have
    ; Notes:
    ;   Code following the macro invocation will be in kSecCode
mFont8      MACRO
      ; These routines are only for 8-pixel-wide glyphs
              IFNE (kFont\1GlyphCols-8)
      FAIL The mFont8Lib macro is only for fonts with 8-pixel-wide glyphs
              ENDC

      ; Build supporting code if necessary
      _mFont8 \2,\3

      ; Code coming, so be in the code section
      SECTION kSecCode

      ; Putc\1 -- Draw a glyph at a specified column and row
      ; Args:
      ;   D0: (word) Glyph to draw---note that this is a word!
      ;   D1: (word) Column receiving the character
      ;   D2: (word) Row receiving the character
      ; Notes:
      ;   Trashes A0-A1/D0,D2
Putc\1:
      MOVEA.L #font\1,A0             ; Load address of our font
      BRA     _Putc8x\2x\3           ; Jump to shared glyph display code

      ; GotoXY\1 -- Designate the screen position for the next call to Print\1
      ; Args:
      ;   D0: (word) Column of the next screen position
      ;   D1: (word) Row of the next screen position
      ; Notes:
      ;   (none)
GotoXY\1:
      ; No need to jump to shared code for this small function
      MOVE.W  D0,zCol\2x\3           ; Set column
      MOVE.W  D1,zRow\2x\3           ; Set row
      RTS                            ; Back to caller

      ; Scroll\1 -- Scroll the entire display up one line
      ; Args:
      ;   (none)
      ; Notes:
      ;   Consumes six words of stack storage
Scroll\1:
      BRA     _Scroll8x\2x\3         ; Jump to shared text scrolling code
      ; No RTS: the shared code returns to the caller

      ; Print\1 -- Print a null-terminated string of 8-bit chars to the display
      ; Args:
      ;   A0: Address of the null-terminated string to print
      ; Notes:
      ;   Wraps text that overflows a line to the following line
      ;   Scrolls the display upward if the cursor falls below the "bottom"
      ;   Printing to the bottom-left row/col will therefore cause scrolling
      ;   Suspends all interrupts while printing
      ;   Trashes A0-A3/D0-D2
Print\1:
      MOVEA.L A0,A2                  ; Move string pointer to A2 for print code
      MOVEA.L #font\1,A3             ; Load address of our font
      BRA     _Print8x\2x\3          ; Jump to shared text printing code
      ; No RTS: the shared code returns to the caller

            ENDM


**** GENERAL CODE AND DATA


    SECTION kSecCode

    ; InitLisaConsoleScreen -- Prepare this library's global data structures
    ; Args:
    ;   (none)
    ; Notes:
    ;   Must be called prior to call to any display routine in this module
InitLisaConsoleScreen:
    MOVE.L  $2A8,zLisaConsoleScreenBase  ; Copy "end of RAM" from ROM data
    SUB.L   #$8000,zLisaConsoleScreenBase  ; Subtract 32k (the screen data)
    RTS                            ; Back to caller


    ; ClearLisaConsoleScreen -- Blank the entire display
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0
ClearLisaConsoleScreen:
    _mLcsIDis                      ; Disable interrupts for speed
    MOVEA.L zLisaConsoleScreenBase,A0  ; Start of the display buffer
    MOVE.W  #$3FCE,D0              ; Loop iterations to blank the whole screen
.lp CLR.W   (A0)+                  ; Blank this word of the display
    DBRA    D0,.lp                 ; On to the next word
    _mLcsIEna                      ; Re-enable interrupts
    RTS                            ; Back to the caller


    SECTION kSecScratch

zLisaConsoleScreenBase:
    DC.L    $12345678              ; Address of beginning of video RAM
