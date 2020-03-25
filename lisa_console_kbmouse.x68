* Apple Lisa I/O library: keyboard and mouse routines.
*
* Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.
*
*
* ## Introduction
*
* This file contains procedures for gathering input from the Apple Lisa's
* keyboard and mouse from the COPS microcontroller on the Lisa's I/O board.
*
* The code for obtaining keyboard input is designed to detect and accommodate
* all the known Lisa keyboard layouts automatically: US, UK, DE, and FR. The
* code translates native keycodes into 8-bit ISO 8859-1 (Latin-1) character
* values. The library notes the state of the Shift and Caps Lock modifier keys
* when performing this translation, but not the Option or Apple modifier keys.
*
* The procedures in this library are not designed to be relocatable---once
* included in your program, the code expects itself, its internal state, and
* its fixed data to remain in the same memory locations.
*
* No procedure in this library alters the existing interrupt handling
* behaviour of the Lisa. Some procedures may be useful in implementations of
* interrupt handlers but have not been tested in this way.
*
*
* ## Usage
*
* This library is written in the dialect of 68000 macro assembly supported by
* the open-source Windows-only EASy68k development environment and simulator
* (http://www.easy68k.com/). Converting the library's source code to a dialect
* compatible with other popular assemblers should not be very difficult.
*
* There is a standalone version of the EASy68k assembler that is usable from a
* Unix command line (https://github.com/rayarachelian/EASy68K-asm). All
* development work on the library used this assembler, and users who don't want
* to use a different assembly dialect are recommended to use it themselves.
*
* To use this library in your own project, the first step is to define three
* symbols that refer to sections of your assembled program:
*
*    - `kSecCode`: a section containing executable code
*    - `kSecData`: a section containing fixed, read-only data
*    - `kSecScratch`: a section containing mutable, temporary data
*
* Next, you can include the library in the conventional way:
*
*    INCLUDE lisa_console_kbmouse.x68   ; Mouse and keyboard library
*
* The procedures in this library are:
*
*    - `InitLisaConsoleKbMouse`: Reset library-internal keyboard and mouse state
*    - `LisaConsolePollKbMouse`: Attempt to read and decode a byte from the COPS
*    - `LisaConsoleWaitForKbMouse`: Block on getting and decoding a COPS byte
*    - `LisaConsoleDelayForKbMouse`: As above, with a timeout
*
* Additionally, the library maintains several in-memory state values that are
* public to its users:
*
*    - `zLisaConsoleKbFault`: $00 if and only if the keyboard is present and OK
*    - `zLisaConsoleKbIntl`: $00 if and only if the keyboard has a US key layout
*    - `zLisaConsoleKbLayout`: Layout byte -- $BF=US, $AF=UK, $AE=DE, $AD=FR
*
*    - `zLisaConsoleKbCode`: Last raw keycode sent by the keyboard
*    - `zLisaConsoleKbChar`: Last Latin-1 character typed by the user
*    - `zLisaConsoleKbOptL`: $00 if and only if the left Option key is up
*    - `zLisaConsoleKbCaps`: $00 if and only if the Caps Lock key is up
*    - `zLisaConsoleKbShift`: $00 if and only if both Shift keys are up
*    - `zLisaConsoleKbApple`: $00 if and only if the Apple key is up
*    - `zLisaConsoleKbOptR`: $00 if and only if the right Option key is up
*
*    - `zLisaConsoleMouseFault`: $00 if and only if the mouse is present and OK
*    - `zLisaConsoleMouseB`: $00 if and only if the mouse button is up
*    - `zLisaConsoleMouseDx`: Signed sum of recent mouse X deltas (you clear)
*    - `zLisaConsoleMouseDy`: Signed sum of recent mouse Y deltas (you clear)
*
* The `zLisaConsoleKbChar` byte is followed by a $00 byte in memory so that
* `zLisaConsoleKbChar` is effectively a null-terminated string (for printing).
*
* Before using any other procedure or data value in this library, the
* `InitLisaConsoleKbMouse` procedure must run to initialise these and other
* (internal-use-only) values. This procedure does not reset the keyboard
* hardware itself, only the library's own state. It's fine to call this
* procedure more than once, although the library may lose track of modifier
* keys that may be down when this occurs.
*
* The remaining three procedures are all dedicated to polling the COPS chip
* with varying amounts of persistence (see also the documentation below). All
* three will return to the caller after retrieving at most one byte, and
* because some kinds of COPS data "phrases" can be longer than a byte
* (including data from devices besides the keyboard or mouse), it's typical to
* call these procedures within a loop that will check whether the COPS should
* be polled again. Each procedure will set the X flag if it recognises that the
* COPS has another byte to process; if set, the procedure should be called
* again immediately to deal with it. There is no need to have specialised
* application code for handling different kinds of multi-byte data---the
* procedures are stateful, keep track of the progress of these phrases between
* calls, and process them when they are complete.
*
* #### Keyboard events
*
* Each full keypress generates two raw events: a key-down event and a key-up
* event. Sometimes these events can be separated by lengthy intervals---for
* example, when the user engages the Caps Lock key, the key-up event won't
* occur until the user releases it, potentially hours later. Raw key events are
* represented by a byte: the high-order bit is key-down (1) or key-up (0), and
* the remaining seven bits are the key code. See the Lisa Hardware Manual (link
* in the Resources section below), or the `kLisaConsoleKbMap*` definitions at
* the end of this file, for tables and figures showing which keys produce which
* key codes.
*
* For a key-down event, the `LisaConsole...KbMouse` procedures store the raw
* code at `zLisaConsoleKbCode`: if it's necessary for a program to react to
* key-downs, one approach is for programs to clear `zLisaConsoleKbCode` and
* check it for changes after each `LisaConsole...KbMouse` procedure call. ($00
* is never a valid key code.) If the key is a modifier key, the procedures also
* store a nonzero value in the appropriate keyboard status byte (starting at
* `zLisaConsoleKbOptL` below).
*
* For a key-up event, the procedures still store the raw key code at
* `zLisaConsoleKbCode` and still update the keyboard status bytes for modifier
* keys, but now they also attempt to translate key codes for non-modifier keys
* to ISO 8859-1 (Latin-1) characters, taking the keyboard layout and the
* modifier key status into account. These characters are stored at
* `zLisaConsoleKbChar`, and any time the procedures have stored a new value
* there, they set the Z flag.
*
* #### Mouse events
*
* The mouse button works much like a keyboard key, but the
* `LisaConsole...KbMouse` procedures treat it differently, setting and clearing
* the `zLisaConsoleMouseB` byte without altering the Z flag. Programs that need
* to monitor the state of the mouse button should check `zLisaConsoleMouseB`
* themselves.
*
* The COPS encodes mouse movements in three-byte "phrases", which the
* procedures decode over three separate calls (cf. above). While decoding, the
* procedures add reported mouse movements to `zLisaConsoleMouseDx` and
* `zLisaConsoleMouseDy`, both signed 16-bit quantities. It is up to the calling
* program to monitor or clear these values between calls to the procedures,
* which contain no code to prevent them from overflowing.
*
* For improved compatibility with LisaEm, the mouse movement code also updates
* the boot ROM's stored mouse position at $0486 (X) and $0488 (Y). These values
* are bounded within [0, 719] and [0, 363] respectively. (Why? In order to
* provide seamless "capture and release" of the emulating computer's mouse,
* LisaEm monitors these values and generates "virtual" mouse events until the
* Lisa's idea of the mouse location lines up with the emulating computer's
* mouse location relative to the LisaEm window.)
*
* If these updates are not desired, set the kSetRomMPos configuration parameter
* below to 0.
*
*
* ## The library's operating requirements
*
* The library assumes that the Lisa's MMU setup and the contents of its first
* $800 bytes of RAM are both in the configurations that the Lisa's boot ROM
* leaves them in after handing control over to user code. These assumptions
*
*    - allow `InitLisaConsoleKbMouse` to use the ROM's keyboard layout ID
*      instead of resetting the keyboard (slow) to get it,
*    - allow the mouse handling code to update the boot ROM's stored mouse
*      position information (cf. above), and
*    - allow the library to address VIA registers at the same memory addresses
*      that the boot ROM does.
*
* Additionally, the library assumes that hard-coded references to keyboard
* layout data and global state in memory will not need to change throughout the
* full runtime of the program.
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
*    - Lisa Hardware Manual
*      https://lisa.sunder.net/LisaHardwareManual1983.pdf
*    - Lisa_Boot_ROM_Asm_Listing.TEXT: Authoritative info for boot ROM ver. H.
*      http://bitsavers.org/pdf/apple/lisa/firmware/Lisa_Boot_ROM_Asm_Listing.TEXT
*    - Lisa keyboard tester: especially its character tables
*      http://john.ccac.rwth-aachen.de:8000/patrick/KBDtester.htm
*
*
* ## Acknowledgements
*
* As with so many of my Lisa hobby software development efforts, the excellent
* technical resources furnished by Ray Arachelian, Patrick Schäfer, and
* bitsavers.org are gratefully acknowledged.
*
*
* ## Revision history
*
* This section records the development of this file as part of the `lisa_io`
* library at <http://github.com/stepleton/lisa_io>.
*
*    - 24 March 2020: Initial release.
*      (Tom Stepleton, stepleton@gmail.com, London)
*
*
* ## Technical notes
*
* *On VIA addresses* -- The Lisa I/O board contains two MOS 6522 VIA chips, but
* only VIA 1 is responsible for interfacing with the COPS microcontroller. This
* code expects to find the VIA 1 IFR control register at $FCDD9B and the ORA
* register at $FCDD83.
*
* *State machine* -- Successive calls to the `LisaConsole...KbMouse` procedures
* advance the library's state through the following state machine:
*
*       [[ 0: Home ]]<---------------------------------------.
*          |                                                  |
*     $00: |`----->[ 1: Mouse X ]-->[ 2: Mouse Y ]-----------'|  Mouse motion
*          |                                                  |
*     $80: |`----->[ 3: COPS says... ]                        |
*          |         |                                        |
*          |    $EF: |`-->[ 4 ]->[ 5 ]->[ 6 ]->[ 7 ]->[ 8 ]--'|  Time (ignored)
*          |         |                                        |
*          |   else:  `--------------------------------------'|  Other item
*          |                                                  |
*    else:  `------------------------------------------------'   Key event
*
* Each arrow between states consumes a byte from the COPS, with specific bytes
* labeled at branching points. Some notes:
*
*    - "Rows" in the diagram correspond to different types of COPS "phrases"
*      (labeled)---the bottom row corresponds to a single byte phrase that
*      corresponds to a keyboard event or the mouse button (and hence after
*      processing it we return to State 0).
*    - States 4-8 are neither named nor interesting: they just discard the five
*      bytes the COPS uses to encode the current time and date (perhaps
*      something to make use of in a later version of this library).
*    - "Other item" refers to one of the COPS's miscellaneous two-byte phrases,
*      encoding things like keyboard layouts and various faults.
*
* The code that processes the byte for arrows coming out of state X begins at
* the symbol `_LCKMD_StateX`, with the `_LisaConsoleKbMouseDecode` helper
* indexing a jump table with `_zLisaConsoleCopsState`.


**** CONFIGURATION


kSetRomMPos EQU  1                 ; Update the boot ROM's mouse position data


**** CONSTANTS


kKbId       EQU  $01B2             ; ROM-set keyboard identifier
kKbVia      EQU  $FCDD81           ; Keyboard VIA memory address
kKbViaIfr   EQU  $1A               ; kKbVia offset to interrupt flag register
kKbViaOra   EQU  $02               ; kKbVia offset to output register A

_kRomMouseX   EQU  $0486           ; Where the boot ROM stores the mouse X pos.
_kRomMouseY   EQU  $0488           ; Where the boot ROM stores the mouse Y pos.


**** CODE


    SECTION kSecCode


    ; InitLisaConsoleKbMouse -- Reset library-internal keyboard and mouse state
    ; Args:
    ;   (none)
    ; Notes:
    ;   MUST be called before using any other routine in this module!
    ;   Doesn't really reset much at all (true resets take almost 2 seconds!)
    ;   Just sets internal state to some default values
    ;   Trashes nothing
InitLisaConsoleKbMouse:
    CLR.B   _zLisaConsoleCopsState   ; Reset internal decoding state

    CLR.B   zLisaConsoleKbFault    ; Let's assume the keyboard is OK again
    CLR.B   zLisaConsoleMouseFault   ; And the mouse too
    MOVE.B  kKbId,zLisaConsoleKbLayout   ; Revert to the KB ID that the ROM got

    CLR.B   zLisaConsoleKbChar     ; Clear keyboard last character
    CLR.B   zLisaConsoleKbCode     ; Clear keyboard last code

    ; CLR.B   zLisaConsoleKbCaps   ; We don't reset caps lock since it sticks...
    CLR.B   zLisaConsoleKbShift    ; Assume shift key is up
    CLR.B   zLisaConsoleKbApple    ; Assume apple key is up
    CLR.B   zLisaConsoleKbOptL     ; Assume left option is up
    CLR.B   zLisaConsoleKbOptR     ; Assume right option is up

    CLR.B   zLisaConsoleMouseB     ; Assume mouse button is up
    CLR.W   zLisaConsoleMouseDx    ; Clear mouse X movement
    CLR.W   zLisaConsoleMouseDy    ; Clear mouse Y movement

    BSR     _LisaConsoleKbSetKbMap   ; Update current keymap in use

    RTS                            ; Back to caller


    ; LisaConsolePollKbMouse - Attempt to read and decode a byte from the COPS
    ; Args:
    ;   (none)
    ; Notes:
    ;   C flag is set if any byte at all has been read from the COPS
    ;   Z flag is set if a glyph key has been fully typed (key down, key up)
    ;   In which case examine zLisaConsoleKbChar for its Latin-1 code
    ;   X flag is set if we should get another byte from the COPS
    ;   Trashes D0-D1/A0-A1
LisaConsolePollKbMouse:
    LEA.L   kKbVia,A1              ; Load the keyboard VIA base address into A1
    MOVE.B  kKbViaIfr(A1),D0       ; Get the COPS interrupt flag register
    BTST.L  #1,D0                  ; Is there a COPS byte waiting for us?
    BNE.S   .gb                    ; If so, get the byte
    ANDI.B  #$FA,CCR               ; Nope, clear Z (no keypress) and C (no data)
    RTS                            ; Back to the caller
.gb MOVE.B  kKbViaOra(A1),D0       ; Copy the byte from the COPS
    BSR.S   _LisaConsoleKbMouseDecode  ; Decode the byte
    ORI.B   #$01,CCR               ; Flag that a byte has been retrieved
    RTS                            ; Back to the caller


    ; LisaConsoleWaitForKbMouse - Block until we can get and decode a COPS byte
    ; Args:
    ;   (none)
    ; Notes:
    ;   Z flag is set if a glyph key has been fully typed (key down, key up)
    ;   In which case examine zLisaConsoleKbChar for its Latin-1 code
    ;   X flag is set if we should get another byte from the COPS
    ;   Trashes D0-D1/A0-A1
LisaConsoleWaitForKbMouse:
    LEA.L   kKbVia,A1              ; Load the keyboard VIA base address into A1
.wb MOVE.B  kKbViaIfr(A1),D0       ; Get the COPS interrupt flag register
    BTST.L  #1,D0                  ; Is there a COPS byte waiting for us?
    BEQ.S   .wb                    ; If not, loop until there is one
    MOVE.B  kKbViaOra(A1),D0       ; Copy the byte from the COPS
    BSR.S   _LisaConsoleKbMouseDecode  ; Decode the byte
    RTS                            ; Back to the caller


    ; LisaConsoleDelayForKbMouse - Pause a bit, try to get/decode a COPS byte
    ; Args:
    ;   D2 (word): Number of iterations to wait for a COPS byte, minus one
    ; Notes:
    ;   C flag is set if any byte at all has been read from the COPS
    ;   Z flag is set if a glyph key has been fully typed (key down, key up)
    ;   In which case examine zLisaConsoleKbChar for its Latin-1 code
    ;   X flag is set if we should get another byte from the COPS
    ;   Trashes D0-D2/A0-A1
LisaConsoleDelayForKbMouse:
    LEA.L   kKbVia,A1              ; Load the keyboard VIA base address into A1
.wb MOVE.B  kKbViaIfr(A1),D0       ; Get the COPS interrupt flag register
    BTST.L  #1,D0                  ; Is there a COPS byte waiting for us?
    BNE.S   .gb                    ; If so, go get it
    DBRA    D2,.wb                 ; Otherwise, keep waiting
    ANDI.B  #$FA,CCR               ; Timeout, clear Z (no keypress), C (no data)
    RTS                            ; Back to the caller
.gb MOVE.B  kKbViaOra(A1),D0       ; Copy the byte from the COPS
    BSR.S   _LisaConsoleKbMouseDecode  ; Decode the byte
    ORI.B   #$01,CCR               ; Flag that a byte has been retrieved
    RTS                            ; Back to the caller


    ; _LisaConsoleKbMouseDecode - Statefully decode a byte from the COPS
    ; Args:
    ;   D0: the byte just read from the COPS via the VIA
    ; Notes:
    ;   Z flag is set if a glyph key has been fully typed (key down, key up)
    ;   In which case examine zLisaConsoleKbChar for its Latin-1 code
    ;   X flag is set if we should get another byte from the COPS
    ;   Trashes D0-D1/A0
_LisaConsoleKbMouseDecode:
    CLR.W   D1                     ; Prepare to load COPS-decoding state
    MOVE.B  _zLisaConsoleCopsState,D1  ; Load COPS-decoding state into a word
    ADD.W   D1,D1                  ; Times 2 to make a jump-table index
    MOVE.W  .jt(PC,D1.W),D1        ; Load relative address from .jt into D0
    JMP     .jt(PC,D1.W)           ; Jump to relative address from .jt
.jt DC.W    _LCKMD_State0-.jt
    DC.W    _LCKMD_State1-.jt      ; And here, the jump table for all
    DC.W    _LCKMD_State2-.jt      ; nine COPS-decoding states
    DC.W    _LCKMD_State3-.jt
    DC.W    _LCKMD_State4-.jt
    DC.W    _LCKMD_State5-.jt
    DC.W    _LCKMD_State6-.jt
    DC.W    _LCKMD_State7-.jt
    DC.W    _LCKMD_State8-.jt


    ; STATE 0: The "home" state -- await a key, mousing, a button, or a status
_LCKMD_State0:
    ANDI.B  #$EF,CCR               ; Clear extend flag---no changes to it below
    TST.B   D0                     ; Did someone move the mouse?
    BEQ.S   .0m                    ;   Prepare to handle it
    CMPI.B  #$80,D0                ; Is this a COPS announcement?
    BEQ.S   .0c                    ;   Prepare to handle it
    CMPI.B  #$06,D0                ; Did someone depress the mouse button?
    BEQ.S   .0d                    ;   Mark it down
    CMPI.B  #$86,D0                ; Did someone reLease the mouse button?
    BEQ.S   .0l                    ;   Mark it down
    CMPI.B  #$07,D0                ; Did someone unplug the mouse?
    BEQ.S   .0u                    ;   Mark it down
    CMPI.B  #$87,D0                ; Did someone plug in the mouse?
    BEQ.S   .0p                    ;   Mark it down
    BRA.S   .0k                    ; It's an ordinary key event, handle it

.0m MOVE.B  #$01,_zLisaConsoleCopsState  ; Prepare for mouse bytes (and clear Z)
    RTS                            ; Back to the caller

.0c MOVE.B  #$03,_zLisaConsoleCopsState  ; Prepare for COPS message (& clear Z)
    RTS                            ; Back to the caller

.0d MOVE.B  #$01,zLisaConsoleMouseB  ; Note mouse button down (and clear Z)
    RTS                            ; Back to the caller

.0l CLR.B   zLisaConsoleMouseB     ; Note mouse button up
    ANDI.B  #$FB,CCR               ; Clear Z flag (this wasn't a keypress)
    RTS                            ; Back to the caller

.0u ORI.B   #$01,zLisaConsoleMouseFault  ; Note mouse unplugged (and clear Z)
    RTS                            ; Back to the caller

.0p ANDI.B  #$FE,zLisaConsoleMouseFault  ; Clear mouse unplugged
    ANDI.B  #$FB,CCR               ; Clear Z flag (this wasn't a keypress)
    RTS                            ; Back to the caller

.0k LEA.L   zLisaConsoleKbOptL,A0  ; Point A0 at modifier key status bytes
    MOVE.B  D0,zLisaConsoleKbCode  ; A key event. Store the keycode
    BPL.S   .0r                    ; Jump for key release, stay for key down

    CMPI.B  #$FC,D0                ; Left option key down?
    BEQ.S   .0v                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$FD,D0                ; Caps lock key down?
    BEQ.S   .0v                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$FE,D0                ; Either shift key down?
    BEQ.S   .0v                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$FF,D0                ; Apple key down?
    BEQ.S   .0v                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$CE,D0                ; Right option down? (If so, fall through)
    BNE.S   .0w                    ; No, just an ordinary key-down event

.0v MOVE.B  #$1,(A0)               ; Mark modifier key-down status
    BSR.S   _LisaConsoleKbSetKbMap   ; Update current keymap in use
.0w ANDI.B  #$FB,CCR               ; Clear Z flag (this wasn't a full keypress)
    RTS                            ; Back to the caller

.0r CMPI.B  #$7C,D0                ; Left option key up?
    BEQ.S   .0x                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$7D,D0                ; Caps lock key up?
    BEQ.S   .0x                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$7E,D0                ; Either shift key up?
    BEQ.S   .0x                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$7F,D0                ; Apple key up?
    BEQ.S   .0x                    ; Mark it and return
    ADDQ.L  #$1,A0                 ; Advance to next modifier key status byte
    CMPI.B  #$4E,D0                ; Right option up? (If so, fall through)
    BNE.S   .0y                    ; No, just an ordinary key-up event

.0x CLR.B   (A0)                   ; Mark modifier key-up status
    BSR.S   _LisaConsoleKbSetKbMap   ; Update current keymap in use
    ANDI.B  #$FB,CCR               ; Clear Z flag (this wasn't a full keypress)
    RTS                            ; Back to the caller

.0y MOVEA.L _zLisaConsoleKbMapPtr,A0   ; Load the keymap pointer into A0
    ANDI.W  #$007F,D0              ; Convert D0 into a displacement index
    MOVE.B  0(A0,D0.W),D0          ; Copy decoded byte for the key
    TST.B   zLisaConsoleKbCaps     ; Is the caps-lock key down?
    BEQ.S   .0z                    ; No, prepare to return
    BSR.S   _LisaConsoleKbDoCapsLock   ; Yes, change the character
.0z MOVE.B  D0,zLisaConsoleKbChar  ; Save the key in RAM
    ORI.B   #$04,CCR               ; Set Z flag (it WAS a full keypress)
    RTS                            ; Back to the caller

    ; More state machine states are defined after these two helpers:


    ; _LisaConsoleKbSetKbMap -- Choose keyboard layout map given current state
    ; Args:
    ;   zLisaConsoleKbLayout: ID byte for current keyboard layout
    ;   zLisaConsoleKbShift: Nonzero iff a shift key is depressed
    ; Notes:
    ;   _zLisaConsoleKbMapPtr will point to the selected keyboard map
    ;   "Current state" is the current keyboard layout and shift key-down state
    ;   Unrecognised keyboard layouts default to the US keyboard map
    ;   Caps Lock handling occurs elsewhere
    ;   Trashes D1/A0
_LisaConsoleKbSetKbMap:
    MOVE.B  zLisaConsoleKbLayout,D1  ; Copy keyboard layout ID locally
    CMPI.B  #$AF,D1                ; Is this a UK keyboard?
    BNE.S   .de                    ;   No, try a different layout
    LEA.L   kLisaConsoleKbMapUk,A0   ; Yes, save UK ptr
    BRA.S   .sh                    ;   Now see if the shift key is down
.de CMPI.B  #$AE,D1                ; Is this a DE keyboard?
    BNE.S   .fr                    ;   No, try a different layout
    LEA.L   kLisaConsoleKbMapDe,A0   ; Ja, save DE ptr
    BRA.S   .sh                    ;   Now see if the shift key is down
.fr CMPI.B  #$AD,D1                ; Is this a FR keyboard?
    BNE.S   .us                    ;   No, give up and say it's American
    LEA.L   kLisaConsoleKbMapFr,A0   ; Oui, save FR ptr
    BRA.S   .sh                    ;   Now see if the shift key is down
.us LEA.L   kLisaConsoleKbMapUs,A0   ; Fall back on America
.sh TST.B   zLisaConsoleKbShift    ; Is the shift key down?
    BEQ.S   .rt                    ; No? Back to caller
    ADDA.W  #(kLisaConsoleKbMapUsS-kLisaConsoleKbMapUs),A0   ; Yes? Bump ptr
.rt MOVE.L  A0,_zLisaConsoleKbMapPtr   ; Save the KB map pointer in RAM
    RTS                            ; Back to the caller


    ; _LisaConsoleKbDoCapsLock -- Apply "caps lock" transform to a character
    ; Args:
    ;   D0: ISO 8859-1 character to make upper-case, if applicable
    ; Notes:
    ;   Comments in the implementation explain the specifics of the transform
    ;   "Trashes" (i.e. applies the transform to) D0
_LisaConsoleKbDoCapsLock
    CMPI.B  #'a',D0                ; Is the character code less than 'a'?
    BLO.S   .rt                    ; If so, its case can't change, so return
    CMPI.B  #'z',D0                ; Is it less than or equal to than 'z'?
    BLE.S   .co                    ; Yes, jump to change its case
.hi CMPI.B  #$E0,D0                ; Is the character code less than 'à'?
    BLO.S   .rt                    ; If so, its case can't change, so return
    CMPI.B  #$F7,D0                ; Is the character '÷'?
    BEQ.S   .rt                    ; If so, its case can't change, so return
    CMPI.B  #$FF,D0                ; Is the character 'ÿ'?
    BEQ.S   .rt                    ; If so, its case can't change, so return
.co ANDI.B  #$DF,D0                ; Convert letter to uppercase
.rt RTS                            ; Back to the caller


    ; State machine states 1-8 follow: depending on your outlook, these are a
    ; continuation of _LisaConsoleKbMouseDecode.

    ; State 1: Collect the first mouse byte
_LCKMD_State1:
    EXT.W   D0                     ; Extend the mouse dx byte to a word
    ADD.W   D0,zLisaConsoleMouseDx   ; Add it to mouse X displacement

            IFNE kSetRomMPos
    ; We update the mouse location in ROM primarily for the benefit of LisaEm,
    ; which monitors that location for seamless tracking of the host OS's mouse
    ; within the emulator window.
    ADD.W   _kRomMouseX,D0         ; Add ROM mouse location to dx
    BGE.S   .bt                    ; If >= 0, skip ahead to enforce top X bound
    CLR.W   D0                     ;   Otherwise, enforce bottom X bound (0)
    BRA.S   .sa                    ;   And store new X mouse location
.bt CMPI.W  #$2D0,D0               ; Is the X location >= 720?
    BLT.S   .sa                    ;   If not, skip ahead to store the location
    MOVE.W  #$2CF,D0               ;   Otherwise, X location is 719
.sa MOVE.W  D0,_kRomMouseX         ; Save mouse X location to ROM location
            ENDC

    MOVE.B  #$02,_zLisaConsoleCopsState  ; Prepare for mouse byte 2 (& clear Z)
    ORI.B   #$10,CCR               ; Caller should retrieve another byte
    RTS                            ; Back to the caller


    ; State 2: Collect the second mouse byte
_LCKMD_State2:
    EXT.W   D0                     ; Extend the mouse dy byte to a word
    ADD.W   D0,zLisaConsoleMouseDy   ; Add it to mouse Y displacement

            IFNE kSetRomMPos
    ; We update the mouse location in ROM primarily for the benefit of LisaEm,
    ; which monitors that location for seamless tracking of the host OS's mouse
    ; within the emulator window.
    ADD.W   _kRomMouseY,D0         ; Add ROM mouse location to dy
    BGE.S   .bt                    ; If >= 0, skip ahead to enforce top Y bound
    CLR.W   D0                     ;   Otherwise, enforce bottom Y bound (0)
    BRA.S   .sa                    ;   And store new Y mouse location
.bt CMPI.W  #$16C,D0               ; Is the Y location >= 364?
    BLT.S   .sa                    ;   If not, skip ahead to store the location
    MOVE.W  #$16B,D0               ;   Otherwise, Y location is 363
.sa MOVE.W  D0,_kRomMouseY         ; Save mouse Y location to ROM location
            ENDC

    CLR.B   _zLisaConsoleCopsState   ; Back to COPS decode state 0
    ANDI.B  #$EB,CCR               ; Clear X (no more bytes) and Z (not a key)
    RTS                            ; Back to the caller


    ; State 3: Decode a special announcement from the COPS
_LCKMD_State3:
    ANDI.B  #$EF,CCR               ; Clear extend---by default, no more bytes
    CLR.B   _zLisaConsoleCopsState   ; Default next COPS decode state is 0
    CMPI.B  #$DF,D0                ; Is this a keyboard ID byte?
    BHI.S   .3c                    ;   No, carry on
    CLR.B   zLisaConsoleKbFault    ;   Yes, clear all keyboard faults
    ANDI.B  #$FD,zLisaConsoleMouseFault  ;   And clear I/O COPS mouse fault
    MOVE.B  D0,zLisaConsoleKbLayout  ; Save keyboard ID byte
    BSR     _LisaConsoleKbSetKbMap   ; Update current keyboard map
    ANDI.B  #$FB,CCR               ;   Clear Z flag (wasn't a full keypress)
    RTS                            ;   And back to the caller
.3c CMPI.B  #$EF,D0                ; Is this a COPS clock report?
    BNE.S   .3k                    ;   No, carry on
    MOVE.B  #$04,_zLisaConsoleCopsState  ; Yes, next state to get bytes (clr Z)
    ORI.B   #$10,CCR               ;   Caller should retrieve more bytes
    RTS                            ;   Back to the caller
.3k CMPI.B  #$FF,D0                ; Is the keyboard COPS bad?
    BNE.S   .3i                    ;   No, carry on
    ORI.B   #$04,zLisaConsoleKbFault   ; Yes, mark it down, clearing Z
    RTS                            ;   Back to the caller
.3i CMPI.B  #$FE,D0                ; Is the I/O board COPS bad?
    BNE.S   .3u                    ;   No, carry on
    ORI.B   #$02,zLisaConsoleKbFault   ; Yes, mark it down, clearing Z
    RTS                            ;   Back to the caller
.3u CMPI.B  #$FD,D0                ; Is the keyboard unplugged?
    BNE.S   .3p                    ;   No, carry on
    ORI.B   #$01,zLisaConsoleKbFault   ; Yes, mark it down, clearing Z
    RTS                            ;   Back to the caller
.3p CMPI.B  #$FB,D0                ; Did the user press the power button?
    BNE.S   .3z                    ;   No, jump to exit (note Z is clear)
    ORI.B   #$08,zLisaConsoleKbFault   ; Yes, mark it down, clearing Z
    ; All other codes (clock interrupt, unrecognised, etc.) we ignore.
.3z RTS                            ;   Back to the caller


    ; States 4-8: Consume and ignore COPS clock data
_LCKMD_State4:
_LCKMD_State5:
_LCKMD_State6:
_LCKMD_State7:
_LCKMD_State8:
    MOVE.B  _zLisaConsoleCopsState,D0  ; Copy COPS-decoding state locally
    CMPI.B  #$08,D0                ; Is it 8 or more?
    BHI.S   .zr                    ; Yes, jump to reset the state to 0, etc
    ORI.B   #$10,CCR               ; No, set extend---more bytes to be read...
    ADDQ.B  #$01,D0                ; ...and set the next COPS state
    BRA.S   .rt                    ; Jump to save COPS data state
.zr ANDI.B  #$EF,CCR               ; Clear extend---no more bytes to read
    CLR.B   D0                     ; The next COPS-decoding state is 0
.rt MOVE.B  D0,_zLisaConsoleCopsState    ; Save COPS-decoding state
    ANDI.B  #$FB,CCR               ; Clear Z flag (this wasn't a full keypress)
    RTS                            ; Back to the caller


**** MUTABLE INTERNAL STATE


    SECTION kSecScratch


* Temporary scratch data

    DS.W    0                      ; Alignment
_zLisaConsoleKbMapPtr:
    DS.L    $00000000              ; Kb map in use (call init, don't forget)
_zLisaConsoleCopsState:
    DC.B    $00                    ; State machine for processing COPS bytes


* Keyboard identification

; TODO: $01 unplugged, $02 I/O board COPS bad, $04 KB COPS bad, $08 power button
zLisaConsoleKbFault:
    DC.B    $00                    ; Is the keyboard present + OK? (Assume yes)
zLisaConsoleKbIntl:
    DC.B    $00                    ; Keyswitch assembly is international?
zLisaConsoleKbLayout:
    DC.B    $00                    ; $BF=US, $AF=UK, $AE=DE, $AD=FR, ??

* Keyboard codes

zLisaConsoleKbCode:
    DC.B    $00                    ; Last raw keycode sent by the keyboard
zLisaConsoleKbChar:
    DC.B    $00                    ; Last character typed by the user
    DC.B    $00                    ; A null terminator for direct printing

* Keyboard status (note: the order of these values is important)

zLisaConsoleKbOptL:
    DC.B    $00                    ; Is the left option key depressed?
zLisaConsoleKbCaps:
    DC.B    $00                    ; Is the caps lock key depressed?
zLisaConsoleKbShift:
    DC.B    $00                    ; Is either shift key depressed?
zLisaConsoleKbApple:
    DC.B    $00                    ; Is the apple key depressed?
zLisaConsoleKbOptR:
    DC.B    $00                    ; Is the right option key depressed?

* Mouse status

; TODO: $01 unplugged, $02 I/O board COPS bad
zLisaConsoleMouseFault:
    DC.B    $00                    ; Is the mouse present + ok? (Assume yes.)
zLisaConsoleMouseB:
    DC.B    $00                    ; Is the mouse button down?

    DS.W    0                      ; Alignment
zLisaConsoleMouseDx:
    DC.W    $0000                  ; Sum of recent mouse dxs (you clear)
zLisaConsoleMouseDy:
    DC.W    $0000                  ; Sum of recent mouse dys (you clear)


**** FIXED DATA


    SECTION kSecData

_kLisaConsoleKbMapUs:              ; Keymap to char (US, no modifier keys)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6',',','.','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    '-','=','\','<','p',$08,$0D,$00,$0A,'0',$00,$00,'/','1',$00,$00  ; 4
    DC.B    '9','0','u','i','j','k','[',']','m','l',';',$27,' ',',','.','o'  ; 5
    DC.B    'e','6','7','8','5','r','t','y','`','f','g','h','v','c','b','n'  ; 6
    DC.B    'a','2','3','4','1','q','s','w',$09,'z','x','d',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapUs      EQU (_kLisaConsoleKbMapUs-$20)

_kLisaConsoleKbMapUsS:             ; Keymap to char (US, +shift)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6',',','.','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    '_','+','|','>','P',$08,$0D,$00,$0A,'0',$00,$00,'?','1',$00,$00  ; 4
    DC.B    '(',')','U','I','J','K','{','}','M','L',':','"',' ','<','>','O'  ; 5
    DC.B    'E','^','&','*','%','R','T','Y','~','F','G','H','V','C','B','N'  ; 6
    DC.B    'A','@','#','$','!','Q','S','W',$09,'Z','X','D',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapUsS     EQU (_kLisaConsoleKbMapUsS-$20)

_kLisaConsoleKbMapUk:              ; Keymap to char (UK, no modifier keys)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6',',','.','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    '-','=','`','\','p',$08,$0D,$00,$0A,'0',$00,$00,'/','1',$00,$00  ; 4
    DC.B    '9','0','u','i','j','k','[',']','m','l',';',$27,' ',',','.','o'  ; 5
    DC.B    'e','6','7','8','5','r','t','y',$A7,'f','g','h','v','c','b','n'  ; 6
    DC.B    'a','2','3','4','1','q','s','w',$09,'z','x','d',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapUk      EQU (_kLisaConsoleKbMapUk-$20)

_kLisaConsoleKbMapUkS:             ; Keymap to char (UK, +shift)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6',',','.','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    '_','+','~','|','P',$08,$0D,$00,$0A,'0',$00,$00,'?','1',$00,$00  ; 4
    DC.B    '(',')','U','I','J','K','{','}','M','L',':','"',' ','<','>','O'  ; 5
    DC.B    'E','^','&','*','%','R','T','Y','#','F','G','H','V','C','B','N'  ; 6
    DC.B    'A','@',$A3,'$','!','Q','S','W',$09,'Z','X','D',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapUkS     EQU (_kLisaConsoleKbMapUkS-$20)

_kLisaConsoleKbMapDe:              ; Keymap to char (DE, no modifier keys)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6','.',',','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    $DF,$27,'#','<','p',$08,$0D,$00,$0A,'0',$00,$00,'-','1',$00,$00  ; 4
    DC.B    '9','0','u','i','j','k',$FC,'+','m','l',$F6,$E4,' ',',','.','o'  ; 5
    DC.B    'e','6','7','8','5','r','t','z','@','f','g','h','v','c','b','n'  ; 6
    DC.B    'a','2','3','4','1','y','s','w',$09,'z','x','d',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapDe      EQU (_kLisaConsoleKbMapDe-$20)

_kLisaConsoleKbMapDeS:             ; Keymap to char (DE, +shift)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6','.',',','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    '?','`','^','>','P',$08,$0D,$00,$0A,'0',$00,$00,'_','1',$00,$00  ; 4
    DC.B    ')','=','U','I','J','K',$DC,'*','M','L',$D6,$C4,' ',';',':','O'  ; 5
    DC.B    'E','&','/','(','%','R','T','Z',$A3,'F','G','H','V','C','B','N'  ; 6
    DC.B    'A','"',$A7,'$','!','Y','S','W',$09,'Z','X','D',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapDeS     EQU (_kLisaConsoleKbMapDeS-$20)

_kLisaConsoleKbMapFr:              ; Keymap to char (FR, no modifier keys)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6','.',',','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    ')','-','`','<','p',$08,$0D,$00,$0A,'0',$00,$00,'=','1',$00,$00  ; 4
    DC.B    $E7,$E0,'u','i','j','k','^','$',',','l','m',$F9,' ',';',':','o'  ; 5
    DC.B    'e',$A7,$E8,'!','(','r','t','y','@','f','g','h','v','c','b','n'  ; 6
    DC.B    'q',$E9,'"',$27,'&','a','s','z',$09,'w','x','d',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapFr      EQU (_kLisaConsoleKbMapFr-$20)

_kLisaConsoleKbMapFrS:             ; Keymap to char (FR, +shift)
          ; _0  _1  _2  _3  _4  _5  _6  _7  _8  _9  _A  _B  _C  _D  _E  _F
    DC.B    $1B,'-','+','*','7','8','9','/','4','5','6','.',',','2','3',$0D  ; 2
    DC.B    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 3
    DC.B    $B0,'_',$A3,'>','P',$08,$0D,$00,$0A,'0',$00,$00,'+','1',$00,$00  ; 4
    DC.B    '9','0','U','I','J','K',$A8,'*','?','L','M','%',' ','.','/','O'  ; 5
    DC.B    'E','6','7','8','5','R','T','Y','#','F','G','H','V','C','B','N'  ; 6
    DC.B    'Q','2','3','4','1','A','S','Z',$09,'W','X','D',$00,$00,$00,$00  ; 7
kLisaConsoleKbMapFrS     EQU (_kLisaConsoleKbMapFrS-$20)

; TODO: Option-modifiers, sticky keys (for accented letters) as well?
