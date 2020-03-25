* # Apple Lisa I/O library: parallel port hard drive routines.
*
* Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.
*
*
* ## Introduction
*
* This file contains a simple and compact (460 bytes compiled) library for
* reading/writing blocks from/to an Apple parallel port hard drive (e.g.
* ProFile, Widget). The library is self-contained (it makes no use of any
* external software or data resources), and all of its code and its internal
* data structures are relocatable. It can read and write to drives attached to
* any Lisa parallel port, including ports on parallel expansion cards.
*
* The library is stateful---it's designed to "speak" to one drive at a time, so
* it caches memory addresses that are specific to the drive it's dealing with.
* It's easy to change which drive the library addresses, but this statefulness
* may make the library unsuitable for rapid access to multiple drives.
*
* For now, the library implements only blocking I/O: none of its procedures
* are interrupt-driven or asynchronous. Anytime the Lisa uses its code to
* address a hard drive, it can do nothing else. This library is therefore
* unlikely to be a good fit for multitasking applications.
*
*
* ## Usage
*
* This library exports three procedures:
*
*    - `ProFileIoSetup`: prepares the library to talk to a specific hard drive
*    - `ProFileIoInit`: sets up the VIAs that interface with the hard drive
*    - `ProFileIo`: read from or write to the hard drive
*
* Even though these names start with "ProFile", the routines can be used to
* communicate with Widget hard drives or with any of the several Apple parallel
* port hard drive emulators (like IDEFile, X/ProFile, or Cameo/Aphid). The
* typical usage method is to call the procedures in the order shown above.
* Arguments and side-effects for each procedure are documented at the places
* below where the procedures are defined.
*
* Note that `ProFileIoSetup` must be called at least once before using the rest
* of the library; otherwise, your program will probably crash. As for
* `ProFileInit`, as long as no other code reconfigures the VIAs after it does,
* it is safe to call this procedure only once for each drive you wish to use.
* This call *must* occur before you try to access the drive with `ProFileIo`.
* "Extra" calls to `ProFileIoSetup` and `ProFileInit` are not harmful.
*
* To switch between drives with initialised VIAs, it's safe to call
* `ProFileIoSetup` with different device ID arguments. No new calls to
* `ProFileInit` are required, provided that each new target drive has already
* been initialised and that the drive's VIAs have not been reconfigured by some
* other code. If these conditions do not apply, you will need to call
* `ProFileInit` again.
*
* The library also exports two data values:
*
*    - `zProFileErrCode`: a byte, the success of the last `ProFileIo` call
*    - `zProFileStatus`: 4 bytes, the ProFile status last read by `ProFileIo`
*
* `zProFileErrCode` can take on these values after a call to `ProFileIo`:
*
*    - $00: the operation succeeded
*    - $01: one of the communication steps has timed out
*    - $02: the hard drive was not ready to communicate
*    - $FF: the hard drive made an unexpected response to a command
*
* The library guarantees that `zProFileStatus` will begin two bytes past the
* location of `zProFileErrCode`.
*
*
* ## The library's operating requirements
*
* The library assumes only that the Lisa's MMU configuration places VIA
* registers in the same locations that the Lisa boot ROM's MMU setup places
* them. If your code does not change the MMU configuration for I/O space access
* from the original boot ROM settings, you don't have to worry about violating
* this assumption. For details of this address arrangement, see the "Technical
* notes" section below.
*
*
* ## Adding the library to your project
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
* To add this library to your own project, either copy and paste its code to
* a convenient place, or use the EASy68k `INCLUDE` directive, like so:
*
*    INCLUDE lisa_profile_io.x68    ; Relocatable ProFile I/O library
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
*    - IDEFile hard drive emulator: especially its protocol descriptions
*      http://john.ccac.rwth-aachen.de:8000/patrick/idefile.htm
*    - Lisa Parallel Interface Card manual:
*      http://bitsavers.org/pdf/apple/lisa/service/029-0176-A_Lisa_Parallel_Interface_Card.pdf
*      *NOTE*: Technical Appendix table 2 has an error -- the two offsets for
*      ORB/IRB should be 1 and 801, not 0 and 800.
*    - Widget ERS: Documentation of Widget hard drive internals
*      http://bitsavers.org/pdf/apple/disk/widget/Widget_ERS.pdf
*    - Lisa_Boot_ROM_Asm_Listing.TEXT: Authoritative info for boot ROM ver. H.
*      http://bitsavers.org/pdf/apple/lisa/firmware/Lisa_Boot_ROM_Asm_Listing.TEXT
*
*
* ## Acknowledgements
*
* Advice from Ray Arachelian is gratefully acknowledged, as are the excellent
* technical resources of LisaEm, bitsavers.org, and Dr. Patrick Schäfer's
* writings on Apple parallel port drives.
*
*
* ## Revision history
*
* This section records the development of this file as part of the `lisa_io`
* library at <http://github.com/stepleton/lisa_io>.
*
*    - 7 March 2020: Initial release.
*      (Tom Stepleton, stepleton@gmail.com, London)
*
*
* ## Technical notes
*
* *On VIA addresses* -- The Lisa I/O board contains two MOS 6522 VIA chips, and
* both are responsible for different aspects of controlling the built-in
* parallel port. VIA 1 (called here the "reset-line VIA" because it only
* controls two reset lines) is only used by `ProFileIoInit`. VIA 2 (called here
* the "main VIA") handles all other control and data lines.
*
* For a parallel port on a parallel expansion card, the "reset-line VIA" and
* the "main VIA" are the same VIA. Each port has its own VIA.
*
* This table shows the memory addresses where this library expects to find the
* VIA control registers it manipulates. These addresses differ for each of the
* seven parallel ports commonly found on a Lisa. An exclamation point marks a
* deviation from an otherwise fairly regular pattern.
*
*           Built-in  Slot 1    Slot 1    Slot 2    Slot 2    Slot 3    Slot 3
*                     Lower     Upper     Lower     Upper     Lower     Upper
*   [Reset-line VIA]
*     xRB   $FCDD81   $FC2001   $FC2801   $FC6001   $FC6801   $FCA001   $FCA801
*    DDRB   $FCDD85!  $FC2011   $FC2811   $FC6011   $FC6811   $FCA011   $FCA811
*
*   [Main VIA]
*     xRB   $FCD901   $FC2001   $FC2801   $FC6001   $FC6801   $FCA001   $FCA801
*     xRA   $FCD909   $FC2009   $FC2809   $FC6009   $FC6809   $FCA009   $FCA809
*    DDRB   $FCD911   $FC2011   $FC2811   $FC6011   $FC6811   $FCA011   $FCA811
*    DDRA   $FCD919   $FC2019   $FC2819   $FC6019   $FC6819   $FCA019   $FCA819
*     PCR   $FCD961   $FCD261   $FC2861   $FC6061   $FC6861   $FCA061   $FCA861
*    PORTA  $FCD979   $FC2079   $FC2879   $FC6079   $FC6879   $FCA079   $FCA879
*
* *Pinouts* -- This table describes the relationship between VIA lines and pins
* of the parallel port:
*
*      [VIA]     [Pin]   [Name]  [Dir]   [Function]             [Port pin]
*    Reset-line   PB5   PARRES/    ?   Parity Reset (?)        (not a pin)
*    Reset-line   PB7   PRES/      →   Controller reset        21
*          Main   CA1   PBSY/      ←   ProFile is busy         16
*          Main   PB1   PBSY/
*          Main   CA2   PSTRB/     →   Data strobe             15
*          Main   CB2   PPARITY/   ←   Data odd parity         18
*          Main   PA_   PD0-PD7    ⇄   Data                    (several)
*          Main   PB0   POCD       ←   Open cable detect       19
*          Main   PB2   DEN/       →   Disk enable             (not a pin)
*          Main   PB3   PR/W/      →   Read/Write              3
*          Main   PB4   PCMD/      →   Command initiation      17
*          Main   PB5   DIAGPAR    ?   Diagnostic parity (?)   (not a pin)
*
* where `[Pin]` is the symbolic name for the pin on a VIA; `[Port pin]` is the
* parallel port pin, and the arrows under `[Dir]` mean the following:
*
*    →: This pin/signal is controlled by the Lisa
*    ←: This pin/signal is controlled by the hard drive
*    ⇄: This pin/signal can be controlled by the Lisa or the hard drive under
*       different circumstances
*    ?: Unknown/not applicable



    ; ProFileIoSetup -- Set up internal state for talking to a specific ProFile
    ; Args:
    ;   D0: Device ID, any of $02,$03,$04,$06,$07,$09,$0A, which have the same
    ;       meanings that the boot ROM uses when reporting the boot device:
    ;           $02 - Built-in ("internal") parallel port / Widget
    ;           $03 - Low port, expansion slot 1
    ;           $04 - High port, expansion slot 1
    ;           $06 - Low port, expansion slot 2
    ;           $07 - High port, expansion slot 2
    ;           $09 - Low port, expansion slot 3
    ;           $0A - High port, expansion slot 3
    ; Notes:
    ;   Trashes D0-D2,A0-A2
ProFileIoSetup:
    ; We begin by setting everything up for the internal parallel port.
    MOVE.W  #$FC,D1                ; Special I/O space starts at $FC0000
    SWAP.W  D1                     ; D1 is now $00FC????
    MOVE.W  #$DD81,D1              ; D1 is the I/O board VIA 1 address $FCDD81
    MOVE.L  D1,A1                  ; Copy the I/O board VIA 1 address to A1
    SUBA.W  #$0480,A1              ; Now A1 is I/O board VIA 2 address $FCD901
    MOVEQ.L #$04,D2                ; And D2 gets the VIA 1 DDRB offset

    ; Now we check whether the user really specified the internal parallel port,
    ; or, if an expansion card port, which one. Note first that valid expansion
    ; card ports are identified as follows:
    ;      S1Low:3  S1Hi:4    S2Low:6  S2Hi:7    S3Low:9  S3Hi:A
    ; We first offset the ID into this arrangement:
    ;      S1Low:0  S1Hi:1    S2Low:3  S2Hi:4    S3Low:6  S3Hi:7
    ; Now any ID below 0 means fall back on the internal port.
    SUBQ.B  #$3,D0                 ; Device ID offset now by -3
    BMI.S   .st                    ; Offset ID < 0 means internal port

    ; Now we shift even further, into the negative numbers.
    ;      S1Low:-8 S1Hi:-7   S2Low:-5 S2Hi:-4   S3Low:-2 S3Hi:-1
    ; Any ID above 0 means fall back on the internal port
    SUBQ.B  #$8,D0                 ; Device ID offset now by -B
    BPL.S   .st                    ; Offset ID >= 0 means internal port

    ; If here, the device is a port on a parallel expansion card. We change the
    ; DDRB offset from $04 to $10 (it's different), then scan (backward) through
    ; the IDs to figure out which expansion slot and connector was specified.
    ; Note how the base address is odd for expansion slot cards, which may have
    ; something to do with Lisa's funny address map.
    MOVEQ.L #$10,D2                ; Update DDRB offset in D2 for the card VIA
    MOVE.W  #$E001,D1              ; D1 is now $FCE001
.aa SUBI.W  #$4000,D1              ; Iter 1: D1 now $FCA001, and so on
    ADDQ.B  #$3,D0                 ; Offset ID += 3
    BMI.S   .aa                    ; Offset ID < 0? Next card
    SUBQ.B  #$1,D0                 ; Offset ID -= 1
    BEQ.S   .bb                    ; Offset ID is 0? Done: lower via
    ADDI.W  #$0800,D1              ; No, add $800 for the upper VIA
.bb MOVE.L  D1,A1                  ; Copy VIA address to A1

    ; Store critical addresses for talking to the ProFile VIAs in the storage
    ; area allocated below. In this first part we store the base and DDRB
    ; addresses for the VIA used for the parity and controller reset lines.
.st LEA.L   _zProFileSetupAddresses(PC),A0
    MOVE.L  D1,(A0)+               ; Store reset-line VIA base (and xRB) address
    ADD.W   D2,D1                  ; Change to reset-line VIA DDRB address
    MOVE.L  D1,(A0)+               ; Store reset-line VIA DDRB address

    ; In this second part, it's addresses for the VIA used for every other part
    ; of ProFile communication.
    LEA.L   $60(A1),A2             ; Compute main VIA PCR address
    MOVE.L  A2,(A0)+               ; Store it
    LEA.L   $10(A1),A2             ; Compute main VIA DDRB address
    MOVE.L  A2,(A0)+               ; Store it
    MOVE.L  A1,(A0)+               ; Save main VIA base (and xRB) address
    LEA.L   $18(A1),A2             ; Compute main VIA DDRA address
    MOVE.L  A2,(A0)+               ; Store it
    LEA.L   $78(A1),A2             ; Compute main VIA PORTA address
    MOVE.L  A2,(A0)+               ; Store it
    LEA.L   $08(A1),A2             ; Compute main VIA xRA address
    MOVE.L  A2,(A0)+               ; Store it

    RTS

***
*** Beginning of the data storage area
***

    ; WARNING: The ordering of elements within this data storage area is very
    ; important---much code depends on it in subtle ways.

    ; This storage area for addresses allows us to load a range of useful VIA
    ; addresses into the address registers all at once via MOVEM.L -- then,
    ; reads and writes to these addresses save space since they're using
    ; indirect addressing (e.g. "(A3)") to write to those addresses.
    DS.W    0                      ; Must be word-aligned
_zProFileSetupAddresses:
    DC.L    '<---'                 ; Reset-line VIA base address (and xRB)
    DC.L    '-Zon'                 ; Reset-line VIA DDRB
    DC.L    'e fo'                 ; Main VIA PCR
    DC.L    'r VI'                 ; Main VIA DDRB
_zProFileMainViaAddrs:
    DC.L    'A ad'                 ; Main VIA base address (and xRB)
    DC.L    'dres'                 ; Main VIA DDRA
    DC.L    'ses-'                 ; Main VIA PORTA
    DC.L    '--->'                 ; Main VIA xRA

    ; A location where we store more descriptive error codes describing failures
    ; in attempts to talk to a ProFile drive. For now, these are:
    ;     $00 (OK), $01 (timed out), $02 (drive not ready), $FF (bad response)
zProFileErrCode:
    DC.B    $00                    ; Last ProFile error code
    DS.W    0                      ; Word alignment

    ; A location where we store the ProFile's four response bytes 
zProFileStatus:
    DC.L    'STAT'

***
*** End of the data storage area
***

    ; ProFileIoInit -- Initialise VIAs for ProFile communication
    ; Args:
    ;   (None)
    ; Notes:
    ;   ProFileIoSetup must be called before using this routine
    ;   Z will be set if anything is connected to the current port
    ;   Does not clear error code at zProFileErrCode
ProFileIoInit:
    MOVEM.L A0-A5,-(SP)            ; Save address registers we will use
    LEA.L   _zProFileSetupAddresses(PC),A0
    MOVEM.L (A0),A0-A5             ; Load VIA addresses
    ; Clear device reset lines
    ORI.B   #$A0,(A0)              ; Raise PRES/ and CRES/ (deactivate reset)
    ORI.B   #$A0,(A1)              ; Set PRES/ and CRES/ to outputs
    ; Set control bits for the control lines VIA
    ANDI.B  #$7B,(A2)              ; This line and next: PARITY/ raises IFR3,
    ORI.B   #$6B,(A2)              ; and PSTRB/ blips down after write to ORA
    ; Set all data lines to inputs
    MOVE.B  #$00,(A5)
    ; Assert (low) disk enable, raise R/W (Lisa reads), raise CMD/ (all idle)
    ORI.B   #$18,(A4)
    ANDI.B  #$FB,(A4)
    ; Set data directions for the control lines
    ANDI.B  #$FC,(A3)              ; This line and next: OCD and BSY/ are inputs
    ORI.B   #$1C,(A3)              ; while DEN, R/W, and CMD/ are outputs
    ; Back to the caller
    BTST.B  #$0,(A4)               ; Is there anything connected out there?
    MOVEM.L (SP)+,A0-A5            ; Restore address registers used
    RTS


    ; _ProFileHandshake -- Perform the ProFile command handshake
    ; Args:
    ;   D0: Expected response byte from ProFile
    ;   A1: Location of zProFileErrCode
    ;   A2-A4: Contents of _zProFileMainViaAddrs up through main VIA PORTA
    ; Notes:
    ;   ProFileIoSetup+ProFileIoInit must be called before using this routine
    ;   Z is set on success; otherwise, errors stored in zProFileErrCode are:
    ;       $00 (OK), $01 (timed out), $FF (bad response)
    ;   This procedure TSTs the error code before returning, so feel free to
    ;       use other flags to distinguish between those values
    ;   Trashes D0
_ProFileHandshake:
    CLR.B   (A1)                   ; Clear the ProFile I/O error code
    ; Initiate handshake
    ANDI.B  #$EF,(A2)              ; Lower CMD/
    MOVE.B  #$00,(A3)              ; Set all data lines to inputs
    ; Await BSY/ going low
    SWAP.W  D0                     ; We'll use the free half of D0 for timing
    MOVE.W  #$FFFF,D0              ; Loop this many times waiting for BSY/
.bl BTST.B  #$1,(A2)               ; Is BSY/ low yet?
    BEQ.S   .cr                    ; Yes, go on to check the disk's response
    NOP                            ; (For timing)
    NOP                            ; (For timing)
    DBRA    D0,.bl                 ; No, try again
    BRA.S   .ti                    ; We timed out waiting, so give up
.cr SWAP.W  D0                     ; Restore the expected response byte in D0
    ; Check expected response from the disk (no handshake); compare to target
    CMP.B   (A4),D0                ; Does the response match the target?
    SNE.B   (A1)                   ; Yes? Errcode := $00; No? Errcode := $FF
    SEQ.B   D0                     ; Yes? D0 := $FF; No? D0 := $00 (vice versa)
    ANDI.W  #$0055,D0              ; Set $xxFF in D0 to $0055; $00 to $0000
    ; Respond to the ProFile
    ANDI.B  #$E7,(A2)              ; Lower R/W (Lisa will write)
    MOVE.B  #$FF,(A3)              ; Set all data lines to outputs
    MOVE.B  D0,(A4)                ; Send out $00 or $55 result (no handshake)
    ORI.B   #$10,(A2)              ; Raise CMD/
    ; Await BSY/ going high (or not if there was an error)
    SWAP.W  D0                     ; D0 is now $0055xxxx or $0000xxxx
    CLR.W   D0                     ; D0 is now $00550000 or $00000000
    LSR.L   #2,D0                  ; D0 is now $00154000 or $00000000
    BSR.S   _ProFileWait           ; Wait on BSY/ for that many cycles
    BNE.S   .qs                    ; BSY/ high? Skip ahead to finish
.ti ORI.B   #$01,(A1)              ; No, so timeout error code (preserves $FF)
    ; Return to quiescent state
.qs MOVE.B  #$00,(A3)              ; Set all data lines to inputs
    ORI.B   #$18,(A2)              ; Raise R/W and CMD/
    TST.B   (A1)                   ; Is error code 0?
    RTS                            ; Exit _ProFileHandshake


    ; _ProFileWait -- Wait for the ProFile to raise BSY/
    ; Args:
    ;   D0: Loop iterations to wait (ought not to be $FFFFFFFF)
    ;   A2: Main ProFile VIA base address
    ; Notes:
    ;   ProFileIoSetup+ProFileIoInit must be called before using this routine
    ;   If Z is 0 (cleared), BSY/ is raised; otherwise we timed out
    ;   Trashes D0
_ProFileWait:
    ADDQ.L  #$1,D0                 ; Because we loop at least once
.lp BTST.B  #$1,(A2)               ; Is BSY/ high yet?
    BNE.S   .rt                    ; Yes, jump to exit
    SUBQ.L  #$1,D0                 ; No, decrement loop counter
    BNE.S   .lp                    ; Keep looping till we hit 0
.rt RTS


    ; We can sometimes save some memory by executing two short jumps to
    ; _ProFileHandshake instead of one long jump.
_ProFileHandshakeHop:
    BRA.S   _ProFileHandshake      ; Carry on to _ProFileHandshake


    ; ProFileIo -- Generic procedure for blocking ProFile reads and writes
    ; Args:
    ;   D1: 3-byte logical block address followed by a ProFile command saying
    ;       what to do to it ($00: read, $01: write, $02: write-verify)
    ;   D2: Retry count (upper byte) and sparing threshold (lower byte); a good
    ;       value for booting is $0A03
    ;   A0: Memory address where the 532 block bytes will be read/written; need
    ;       not be word-aligned
    ; Notes:
    ;   ProFileIoSetup+ProFileIoInit must be called before using this routine
    ;   Z is set on success; otherwise, errors stored in zProFileErrCode are:
    ;       $00 (OK), $01 (timed out), $02 (drive not ready), $FF (bad response)
    ;   On return, A0 will point just past the end of the read/write buffer
    ;   Trashes D0/A0, guaranteed NOT to trash D1 or D2
ProFileIo:
    ; Prepare registers
    MOVEM.L A1-A5,-(SP)            ; Save registers used by this function
    LEA.L   _zProFileMainViaAddrs(PC),A1   ; Load key I/O addresses into A2-A5
    MOVEM.L (A1)+,A2-A5            ; Load, and now A1 refers to the error code!
    ; Disable interrupts
    MOVE.W  SR,-(SP)               ; Save status register on the stack
    ORI.W   #$0700,SR              ; Disable all three interrupt levels
    ; Misc remaining setup
    CLR.B   (A1)                   ; Clear the ProFile I/O error code

    ; Wait a spell for the drive to come alive (more of a check really)
    MOVEQ.L #$08,D0                ; BSY/ wait loop is $00000008 cycles
    SWAP.W  D0                     ; Now it is $00080000 cycles
    BSR.S   _ProFileWait           ; Wait now on BSY/
    BNE.S   .h1                    ; Drive is not busy! Carry on
    ADDQ.B  #2,(A1)                ; Drive was not ready; first, mark it...
    BRA.W   .rt                    ; ...then jump to give up

    ; Initial handshake
.h1 MOVEQ.L #$01,D0                ; Drive should respond to handshake with $01
    BSR.S   _ProFileHandshakeHop   ; Try the handshake
    BMI.W   .rt                    ; Response mismatch ($FF), give up
    BEQ.S   .co                    ; Handshake successful, carry on
    MOVEQ.L #$08,D0                ; Drive timed out; try a little wait...
    LSL.L   #$6,D0                 ; ...of 512 cycles
    BSR.S   _ProFileWait           ; Wait now on BSY/
    BEQ.S   .rt                    ; Didn't wake up; give up, error already $01
    ; Try to handshake again
    MOVEQ.L #$01,D0                ; Drive should respond to handshake with $01
    BSR.S   _ProFileHandshakeHop   ; Try the handshake
    BNE.S   .rt                    ; Failed again; give up

    ; Send command bytes
.co ANDI.B  #$F7,(A2)              ; Lower R/W
    MOVE.B  #$FF,(A3)              ; Set all data lines to outputs

    MOVEQ.L #$03,D0                ; Loop four times, rotating through...
.cl MOVE.B  D1,(A5)                ; ...writing the command byte and then...
    ROL.L   #$8,D1                 ; ...the three block address bytes, with...
    DBRA    D0,.cl                 ; ...the original command restored at the end

    ROL.W   #$8,D2
    MOVE.B  D2,(A5)                ; Copy out retry count
    ROL.W   #$8,D2
    MOVE.B  D2,(A5)                ; Copy out sparing threshold

    MOVE.B  #$00,(A3)              ; Set all data lines to inputs
    ORI.B   #$08,(A2)              ; Raise R/W

    ; Get acknowledgement handshake
    MOVE.B  D1,D0                  ; Copy command byte to D0
    ADDQ.B  #$02,D0                ; Expected reply is command byte + 2
    BSR.S   _ProFileHandshakeHop   ; Try the handshake
    BNE.S   .rt                    ; Failed; give up

    ; Now, whether we are reading or writing, we're going to move $214 bytes,
    ; and we can set up the loop counter in D0 ahead of time
    MOVE.W  #$0213,D0              ; One less than how many bytes to read/write

    ; Write out data bytes if we are writing
    TST.B   D1                     ; Are we writing?
    BEQ.S   .sb                    ; No, jump ahead to get status bytes
    ANDI.B  #$F7,(A2)              ; Lower R/W
    MOVE.B  #$FF,(A3)              ; Set all data lines to outputs
.wl MOVE.B  (A0)+,(A5)             ;   Write out a byte and advance the pointer
    DBRA    D0,.wl                 ;   Loop to write the next byte
    MOVE.B  #$00,(A3)              ; Set all data lines to inputs
    ORI.B   #$08,(A2)              ; Raise R/W

    ; Get data write acknowledgement hanshake
    MOVEQ.L #$06,D0                ; We expect to see $06 here
    BSR.W   _ProFileHandshake      ; Try handshake (our "hop" is too far now)
    BNE.S   .rt                    ; Failed; give up

    ; Read status bytes into zProFileStatus
.sb LEA.L   zProFileStatus(PC),A4  ; Reuse A4 now to receive status bytes
    MOVE.B  (A5),(A4)+             ; Read status byte 0
    MOVE.B  (A5),(A4)+             ; Read status byte 1
    MOVE.B  (A5),(A4)+             ; Read status byte 2
    MOVE.B  (A5),(A4)+             ; Read status byte 3

    ; Read in data bytes if we are reading
    TST.B   D1                     ; Are we reading?
    BNE.S   .rt                    ; No, jump ahead to finish
.rl MOVE.B  (A5),(A0)+             ;   Read in a byte and advance the pointer
    DBRA    D0,.rl                 ;   Loop to read the next byte

    ; Re-enable interrupts and do remaining cleanup
.rt MOVE.W  (SP)+,SR               ; Restore SR from the stack (for interrupts)
    TST.B   (A1)                   ; Is the error code 0?
    MOVEM.L (SP)+,A1-A5            ; Restore address registers used
    RTS
