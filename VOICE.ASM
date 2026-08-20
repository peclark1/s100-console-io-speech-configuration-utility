; VOICE.ASM - IMSAI / S-100 V-Stamp RC8660 Voice Laboratory
; Version 1.2 - 2026-08-16
; CP/M 2.2, ORG 0100H. SCC-B A0H/A2H, 19200 8N1.
;
; ---------------------------------------------------------------------------
; OVERVIEW
; ---------------------------------------------------------------------------
; VOICE.COM is an interactive CP/M utility for experimenting with the
; RC Systems V-Stamp / RC8660 speech synthesizer connected to channel B of
; the S100computers Serial I/O V3 board.
;
; Console input/output is handled through CP/M BDOS.  Speech data and RC8660
; control commands are sent directly through the Z85C30 SCC channel B.
;
; Startup sequence:
;   1. Initialize the SCC for the known-working 19200 8N1 configuration.
;   2. Load factory defaults into RAM.
;   3. Try to load VOICE.CFG from the current CP/M drive/user area.
;   4. Apply the resulting configuration to the RC8660.
;   5. Display the interactive menu.
;
; VOICE.CFG occupies one 128-byte CP/M record.  The format is documented
; immediately above LOADCONFIG/SAVECONFIG below.
;
; RC8660 parameter command format used by SENDCMD:
;
;       CTRL-A  <decimal value>  <command letter>  CR
;
; For example, volume 7 is transmitted as CTRL-A, "7", "V", CR.
;
; Parameter command letters used here:
;       O = voice preset
;       V = volume
;       P = pitch
;       X = tone
;       S = speed
;       E = expression
;       A = articulation
;       F = formant
;       R = reverb
;
; KNOWNMASK tracks which individual parameters are explicitly known rather
; than inherited from a voice preset:
;       bit 0  01H  volume
;       bit 1  02H  pitch
;       bit 2  04H  tone
;       bit 3  08H  speed
;       bit 4  10H  expression
;       bit 5  20H  articulation
;       bit 6  40H  formant
;       bit 7  80H  reverb
;
; Selecting a voice preset clears KNOWNMASK because the preset changes several
; RC8660 parameters internally.  As the user overrides individual settings,
; the corresponding bits are set again.  APPLYCONFIG therefore sends the
; preset first, then only the explicitly known overrides.
;
; CFGSTATUS values:
;       0 = factory defaults / no configuration file
;       1 = configuration loaded or saved successfully
;       2 = configuration modified in RAM but not saved
;       3 = save failed
;       4 = VOICE.CFG existed but was invalid
;
; Carry flag conventions used by several helper routines:
;       READNUM     CY=1 invalid input, CY=0 success (A=value)
;       SAVECONFIG  CY=1 failure,       CY=0 success
;       TXCHAR      CY=1 SCC timeout,    CY=0 character transmitted
;
; ---------------------------------------------------------------------------
; CP/M AND HARDWARE CONSTANTS
; ---------------------------------------------------------------------------

BDOS EQU 0005H                    ; CP/M BDOS entry point

BCTL EQU 0A0H                    ; Z85C30 channel B control/status port
BDTA EQU 0A2H                    ; Z85C30 channel B data port

CR EQU 0DH
LF EQU 0AH
ESC EQU 1BH
CTRLA EQU 01H                    ; RC8660 parameter-command introducer

; CP/M BDOS function numbers used by the configuration-file code.
FOPEN EQU 15
FCLOSE EQU 16
FDELETE EQU 19
FREAD EQU 20
FWRITE EQU 21
FMAKE EQU 22
SETDMA EQU 26

ORG 0100H

; ---------------------------------------------------------------------------
; PROGRAM STARTUP AND MAIN COMMAND DISPATCH
; ---------------------------------------------------------------------------

START LXI SP,STACKTOP
CALL SCCINITB                     ; Configure SCC-B for RC8660 serial link
CALL FACTORYRAM                   ; Establish a safe configuration first
CALL LOADCONFIG                   ; Override defaults if VOICE.CFG is valid
CALL APPLYCONFIG                  ; Send resulting settings to synthesizer
CALL SHOWSCREEN

; BDOS function 1 reads and echoes one console character.  UPPER lets all menu
; commands be entered in either upper- or lower-case.
MAIN MVI C,1
CALL BDOS
CALL UPPER
PUSH PSW
CALL CRLF
POP PSW

; Menu dispatch.
CPI 'Q'
JZ QUIT
CPI 'V'
JZ SETVOICE
CPI 'N'
JZ NEXTVOICE
CPI 'L'
JZ SETVOL
CPI 'P'
JZ SETPITCH
CPI 'T'
JZ SETTONE
CPI 'S'
JZ SETSPEED
CPI 'E'
JZ SETEXPR
CPI 'A'
JZ SETART
CPI 'F'
JZ SETFORM
CPI 'R'
JZ SETREVERB
CPI 'C'
JZ CUSTOMTEXT
CPI 'W'
JZ SAVECFG
CPI 'D'
JZ DEFAULTS
CPI ' '
JZ TESTVOICE
CPI '?'
JZ REDRAW
JMP REDRAW                       ; Ignore unknown commands and redraw

; ---------------------------------------------------------------------------
; MENU COMMAND HANDLERS
; ---------------------------------------------------------------------------

; Select one of the eleven RC8660 voice presets (0-10).
;
; A preset changes multiple internal speech parameters, so individual values
; are no longer known after the preset is selected.  Clear KNOWNMASK and let
; subsequent manual changes establish explicit overrides.
SETVOICE LXI D,PROMPTVOICE
CALL PRINTS
MVI B,10                         ; Maximum accepted value
CALL READNUM
JC BADVALUE
STA CURVOICE
XRA A
STA KNOWNMASK
CALL MARKDIRTY
LDA CURVOICE
MVI C,'O'
CALL SENDCMD
CALL SAYTEST
JMP REDRAW

; Advance to the next preset, wrapping 10 -> 0.
NEXTVOICE LDA CURVOICE
INR A
CPI 11
JC NVOK
XRA A
NVOK STA CURVOICE
XRA A
STA KNOWNMASK                    ; New preset invalidates old overrides
CALL MARKDIRTY
LDA CURVOICE
MVI C,'O'
CALL SENDCMD
CALL SAYTEST
JMP REDRAW

; Each parameter handler follows the same pattern:
;   - Prompt and validate a decimal value.
;   - Store it in RAM.
;   - Mark that parameter as an explicit override in KNOWNMASK.
;   - Mark the overall configuration dirty.
;   - Send the RC8660 command.
;   - Speak a short sample so the effect can be heard immediately.

SETVOL LXI D,PROMPTVOL
CALL PRINTS
MVI B,9
CALL READNUM
JC BADVALUE
STA CURVOL
LDA KNOWNMASK
ORI 01H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURVOL
MVI C,'V'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETPITCH LXI D,PROMPTPITCH
CALL PRINTS
MVI B,99
CALL READNUM
JC BADVALUE
STA CURPITCH
LDA KNOWNMASK
ORI 02H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURPITCH
MVI C,'P'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETTONE LXI D,PROMPTTONE
CALL PRINTS
MVI B,2
CALL READNUM
JC BADVALUE
STA CURTONE
LDA KNOWNMASK
ORI 04H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURTONE
MVI C,'X'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETSPEED LXI D,PROMPTSPEED
CALL PRINTS
MVI B,13
CALL READNUM
JC BADVALUE
STA CURSPEED
LDA KNOWNMASK
ORI 08H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURSPEED
MVI C,'S'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETEXPR LXI D,PROMPTEXPR
CALL PRINTS
MVI B,9
CALL READNUM
JC BADVALUE
STA CUREXPR
LDA KNOWNMASK
ORI 10H
STA KNOWNMASK
CALL MARKDIRTY
LDA CUREXPR
MVI C,'E'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETART LXI D,PROMPTART
CALL PRINTS
MVI B,9
CALL READNUM
JC BADVALUE
STA CURART
LDA KNOWNMASK
ORI 20H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURART
MVI C,'A'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETFORM LXI D,PROMPTFORM
CALL PRINTS
MVI B,99
CALL READNUM
JC BADVALUE
STA CURFORM
LDA KNOWNMASK
ORI 40H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURFORM
MVI C,'F'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

SETREVERB LXI D,PROMPTREVERB
CALL PRINTS
MVI B,9
CALL READNUM
JC BADVALUE
STA CURREVERB
LDA KNOWNMASK
ORI 80H
STA KNOWNMASK
CALL MARKDIRTY
LDA CURREVERB
MVI C,'R'
CALL SENDCMD
CALL SAYSHORT
JMP REDRAW

; Read a replacement test phrase with CP/M BDOS function 10.
; TEXTBUF uses the standard buffered-console-input layout:
;       byte 0 = maximum input length
;       byte 1 = actual input length returned by BDOS
;       byte 2... = characters
;
; An empty line leaves the current phrase unchanged.
CUSTOMTEXT LXI D,PROMPTTEXT
CALL PRINTS
LXI D,TEXTBUF
MVI C,10
CALL BDOS
CALL CRLF
LDA TEXTBUF+1
ORA A
JZ REDRAW
STA TESTLEN
MOV B,A
LXI H,TEXTBUF+2
LXI D,TESTTEXT
CTCOPY MOV A,M
STAX D
INX H
INX D
DCR B
JNZ CTCOPY
CALL MARKDIRTY
CALL SAYTEST
JMP REDRAW

; W writes the current RAM configuration to VOICE.CFG.
SAVECFG CALL SAVECONFIG
JNC REDRAW
LXI D,SAVEERR
CALL PRINTS
CALL WAITKEY
JMP REDRAW

; D restores the built-in defaults in RAM and immediately applies them.
; They are not persistent until the user presses W.
DEFAULTS CALL FACTORYRAM
CALL APPLYCONFIG
CALL MARKDIRTY
CALL SAYSHORT
JMP REDRAW

TESTVOICE CALL SAYTEST
JMP REDRAW

BADVALUE LXI D,BADMSG
CALL PRINTS
CALL WAITKEY
JMP REDRAW

REDRAW CALL SHOWSCREEN
JMP MAIN

; CP/M warm-start entry at 0000H returns to the CCP.
QUIT LXI D,EXITMSG
CALL PRINTS
JMP 0000H

; ---------------------------------------------------------------------------
; SCREEN DISPLAY
; ---------------------------------------------------------------------------

; Draw the complete screen from current RAM state.  CLEARSTR is an ANSI
; clear-screen/home sequence; the console device must understand those escapes.
SHOWSCREEN LXI D,CLEARSTR
CALL PRINTS
LXI D,BANNER
CALL PRINTS

LXI D,LVOICE
CALL PRINTS
LDA CURVOICE
CALL PRINTDEC
MVI E,' '
CALL PUTC
CALL PRINTVNAME
CALL CRLF

LXI D,LVOL
CALL PRINTS
MVI B,01H
LXI H,CURVOL
CALL SHOWPARAM

LXI D,LPITCH
CALL PRINTS
MVI B,02H
LXI H,CURPITCH
CALL SHOWPARAM

; Tone is special because, when explicitly known, the numeric value also gets
; a descriptive Bass/Normal/Treble label.
LXI D,LTONE
CALL PRINTS
LDA KNOWNMASK
ANI 04H
JZ TONPRE
LDA CURTONE
CALL PRINTDEC
MVI E,' '
CALL PUTC
LDA CURTONE
ORA A
JZ TONBASS
CPI 1
JZ TONNORM
LXI D,TREBLE
CALL PRINTS
JMP TONEND
TONBASS LXI D,BASS
CALL PRINTS
JMP TONEND
TONNORM LXI D,NORMAL
CALL PRINTS
JMP TONEND
TONPRE LXI D,PRESET
CALL PRINTS
TONEND CALL CRLF

LXI D,LSPEED
CALL PRINTS
MVI B,08H
LXI H,CURSPEED
CALL SHOWPARAM

LXI D,LEXPR
CALL PRINTS
MVI B,10H
LXI H,CUREXPR
CALL SHOWPARAM

LXI D,LART
CALL PRINTS
MVI B,20H
LXI H,CURART
CALL SHOWPARAM

LXI D,LFORM
CALL PRINTS
MVI B,40H
LXI H,CURFORM
CALL SHOWPARAM

LXI D,LREVERB
CALL PRINTS
MVI B,80H
LXI H,CURREVERB
CALL SHOWPARAM

LXI D,LCONFIG
CALL PRINTS
CALL SHOWCFGSTATUS
CALL CRLF

LXI D,LPHRASE
CALL PRINTS
CALL CRLF
LXI D,PHRASEIND
CALL PRINTS
CALL PRINTPHRASE
CALL CRLF

LXI D,MENU
CALL PRINTS
RET

; SHOWPARAM
;   B  = KNOWNMASK bit for this parameter
;   HL = address of the current parameter byte
;
; If the bit is clear, display "(preset)" because the actual value is inherited
; from the currently selected RC8660 preset and is not explicitly known.
SHOWPARAM LDA KNOWNMASK
ANA B
JZ SHPRESET
MOV A,M
CALL PRINTDEC
CALL CRLF
RET
SHPRESET LXI D,PRESET
CALL PRINTS
CALL CRLF
RET

; ---------------------------------------------------------------------------
; CONFIGURATION STATE IN RAM
; ---------------------------------------------------------------------------

; Load the built-in starting values and default test phrase.
;
; KNOWNMASK is FFH here because these are explicit values that APPLYCONFIG
; should send after selecting voice 0.  LOADCONFIG may replace all of them.
FACTORYRAM XRA A
STA CURVOICE
MVI A,5
STA CURVOL
MVI A,50
STA CURPITCH
MVI A,1
STA CURTONE
MVI A,5
STA CURSPEED
MVI A,5
STA CUREXPR
MVI A,5
STA CURART
MVI A,50
STA CURFORM
XRA A
STA CURREVERB
MVI A,0FFH
STA KNOWNMASK
XRA A
STA CFGSTATUS

; Copy the built-in phrase into the writable TESTTEXT buffer.
MVI A,DEFAULTEND-DEFAULTMSG
STA TESTLEN
MOV B,A
LXI H,DEFAULTMSG
LXI D,TESTTEXT
FRCPY MOV A,M
STAX D
INX H
INX D
DCR B
JNZ FRCPY
RET

; Send the complete logical configuration to the RC8660.
;
; The preset must be sent first.  Only parameter bits marked in KNOWNMASK are
; then transmitted as explicit overrides.  This is what preserves the behavior
; of a preset whose individual internal values are not known to the program.
APPLYCONFIG LDA CURVOICE
MVI C,'O'
CALL SENDCMD

LDA KNOWNMASK
ANI 01H
JZ AP1
LDA CURVOL
MVI C,'V'
CALL SENDCMD

AP1 LDA KNOWNMASK
ANI 02H
JZ AP2
LDA CURPITCH
MVI C,'P'
CALL SENDCMD

AP2 LDA KNOWNMASK
ANI 04H
JZ AP3
LDA CURTONE
MVI C,'X'
CALL SENDCMD

AP3 LDA KNOWNMASK
ANI 08H
JZ AP4
LDA CURSPEED
MVI C,'S'
CALL SENDCMD

AP4 LDA KNOWNMASK
ANI 10H
JZ AP5
LDA CUREXPR
MVI C,'E'
CALL SENDCMD

AP5 LDA KNOWNMASK
ANI 20H
JZ AP6
LDA CURART
MVI C,'A'
CALL SENDCMD

AP6 LDA KNOWNMASK
ANI 40H
JZ AP7
LDA CURFORM
MVI C,'F'
CALL SENDCMD

AP7 LDA KNOWNMASK
ANI 80H
JZ APDONE
LDA CURREVERB
MVI C,'R'
CALL SENDCMD

APDONE RET

; Any user-visible change means RAM no longer matches the saved file.
MARKDIRTY MVI A,2
STA CFGSTATUS
RET

; ---------------------------------------------------------------------------
; VOICE.CFG FILE FORMAT AND CP/M FILE I/O
; ---------------------------------------------------------------------------
;
; VOICE.CFG is exactly one 128-byte CP/M record:
;
;   Offset  Size  Meaning
;   ------  ----  -----------------------------------------------------------
;      0      4   Signature "VC12"
;      4      1   File-format version (currently 1)
;      5      1   Voice preset, 0-10
;      6      1   KNOWNMASK
;      7      1   Volume, 0-9
;      8      1   Pitch, 0-99
;      9      1   Tone, 0-2
;     10      1   Speed, 0-13
;     11      1   Expression, 0-9
;     12      1   Articulation, 0-9
;     13      1   Formant, 0-99
;     14      1   Reverb, 0-9
;     15      1   Test-phrase length, 0-76
;     16     76   Test-phrase bytes
;     92      1   8-bit additive checksum of bytes 0-91
;     93     35   Reserved / zero-filled
;
; INITFCB starts from CFGFCBT each time because CP/M BDOS calls modify fields
; within an FCB (extent, record position, allocation information, etc.).
;
; LOADCONFIG assumes FACTORYRAM has already run.  If the file is absent or
; invalid, the factory values remain in RAM and only CFGSTATUS changes.

LOADCONFIG CALL INITFCB

; Open VOICE.CFG in the current drive/user area.  CP/M returns FFH on failure.
LXI D,CFGFCB
MVI C,FOPEN
CALL BDOS
CPI 0FFH
JZ LCNOFILE

; Temporarily point the CP/M DMA address at our 128-byte configuration buffer.
LXI D,CFGBUF
MVI C,SETDMA
CALL BDOS

; Read the first (and only) 128-byte record.
LXI D,CFGFCB
MVI C,FREAD
CALL BDOS
ORA A
JNZ LCREADBAD
CALL CLOSECFG

; Validate signature "VC12" and format version 1.
LDA CFGBUF
CPI 'V'
JNZ LCINVALID
LDA CFGBUF+1
CPI 'C'
JNZ LCINVALID
LDA CFGBUF+2
CPI '1'
JNZ LCINVALID
LDA CFGBUF+3
CPI '2'
JNZ LCINVALID
LDA CFGBUF+4
CPI 1
JNZ LCINVALID

; Compute the 8-bit additive checksum over bytes 0-91.
LXI H,CFGBUF
MVI B,92
MVI C,0
LCSUM MOV A,C
ADD M
MOV C,A
INX H
DCR B
JNZ LCSUM
LDA CFGBUF+92
CMP C
JNZ LCINVALID

; Range-check every persisted value before accepting the file.
; CPI tests one greater than the largest legal value.
LDA CFGBUF+5
CPI 11
JNC LCINVALID
LDA CFGBUF+7
CPI 10
JNC LCINVALID
LDA CFGBUF+8
CPI 100
JNC LCINVALID
LDA CFGBUF+9
CPI 3
JNC LCINVALID
LDA CFGBUF+10
CPI 14
JNC LCINVALID
LDA CFGBUF+11
CPI 10
JNC LCINVALID
LDA CFGBUF+12
CPI 10
JNC LCINVALID
LDA CFGBUF+13
CPI 100
JNC LCINVALID
LDA CFGBUF+14
CPI 10
JNC LCINVALID
LDA CFGBUF+15
CPI 77
JNC LCINVALID

; Copy validated settings from the file record into working RAM.
LDA CFGBUF+5
STA CURVOICE
LDA CFGBUF+6
STA KNOWNMASK
LDA CFGBUF+7
STA CURVOL
LDA CFGBUF+8
STA CURPITCH
LDA CFGBUF+9
STA CURTONE
LDA CFGBUF+10
STA CURSPEED
LDA CFGBUF+11
STA CUREXPR
LDA CFGBUF+12
STA CURART
LDA CFGBUF+13
STA CURFORM
LDA CFGBUF+14
STA CURREVERB
LDA CFGBUF+15
STA TESTLEN

; Copy only the actual phrase length.  TESTTEXT does not need a terminator
; because TESTLEN controls both display and transmission.
ORA A
JZ LCNOPHCPY
MOV B,A
LXI H,CFGBUF+16
LXI D,TESTTEXT
LCPHCPY MOV A,M
STAX D
INX H
INX D
DCR B
JNZ LCPHCPY

LCNOPHCPY MVI A,1
STA CFGSTATUS
CALL RESETDMA
ORA A                             ; Clear carry before successful return
RET

; A physical/BDOS read error is treated as an invalid configuration.
LCREADBAD CALL CLOSECFG
LCINVALID MVI A,4
STA CFGSTATUS
CALL RESETDMA
STC
RET

; Missing VOICE.CFG is normal; leave factory values in place.
LCNOFILE XRA A
STA CFGSTATUS
CALL RESETDMA
STC
RET

; Build a fresh 128-byte configuration record and write it to VOICE.CFG.
SAVECONFIG LXI H,CFGBUF
MVI B,128

; Zero the entire record so unused/reserved bytes have deterministic contents.
SCZERO MVI M,0
INX H
DCR B
JNZ SCZERO

; Signature and file-format version.
MVI A,'V'
STA CFGBUF
MVI A,'C'
STA CFGBUF+1
MVI A,'1'
STA CFGBUF+2
MVI A,'2'
STA CFGBUF+3
MVI A,1
STA CFGBUF+4

; Persist the current working settings.
LDA CURVOICE
STA CFGBUF+5
LDA KNOWNMASK
STA CFGBUF+6
LDA CURVOL
STA CFGBUF+7
LDA CURPITCH
STA CFGBUF+8
LDA CURTONE
STA CFGBUF+9
LDA CURSPEED
STA CFGBUF+10
LDA CUREXPR
STA CFGBUF+11
LDA CURART
STA CFGBUF+12
LDA CURFORM
STA CFGBUF+13
LDA CURREVERB
STA CFGBUF+14
LDA TESTLEN
STA CFGBUF+15

; Copy the variable-length phrase into the fixed 76-byte phrase field.
ORA A
JZ SCNOPHCPY
MOV B,A
LXI H,TESTTEXT
LXI D,CFGBUF+16
SCPHCPY MOV A,M
STAX D
INX H
INX D
DCR B
JNZ SCPHCPY

; Additive checksum of bytes 0-91 goes in byte 92.
SCNOPHCPY LXI H,CFGBUF
MVI B,92
MVI C,0
SCSUM MOV A,C
ADD M
MOV C,A
INX H
DCR B
JNZ SCSUM
MOV A,C
STA CFGBUF+92

; CP/M has no truncate/create-over-existing operation through this simple FCB
; path, so delete any old file first, then create a new one.
CALL INITFCB
LXI D,CFGFCB
MVI C,FDELETE
CALL BDOS

CALL INITFCB
LXI D,CFGFCB
MVI C,FMAKE
CALL BDOS
CPI 0FFH
JZ SCFAIL

; Write one 128-byte record from CFGBUF.
LXI D,CFGBUF
MVI C,SETDMA
CALL BDOS
LXI D,CFGFCB
MVI C,FWRITE
CALL BDOS
ORA A
JNZ SCWRITEFAIL

; Closing lets CP/M finish directory bookkeeping.
CALL CLOSECFG
CPI 0FFH
JZ SCFAIL

CALL RESETDMA
MVI A,1
STA CFGSTATUS
ORA A                             ; Clear carry = success
RET

SCWRITEFAIL CALL CLOSECFG
SCFAIL CALL RESETDMA
MVI A,3
STA CFGSTATUS
STC
RET

; Copy the pristine FCB template into the working FCB.
INITFCB LXI H,CFGFCBT
LXI D,CFGFCB
MVI B,36
IFCBLP MOV A,M
STAX D
INX H
INX D
DCR B
JNZ IFCBLP
RET

; Tail-jump into BDOS so its RET returns directly to our caller.
CLOSECFG LXI D,CFGFCB
MVI C,FCLOSE
JMP BDOS

; Restore CP/M's conventional default DMA buffer at 0080H before returning
; control to normal console/CCP processing.
RESETDMA LXI D,0080H
MVI C,SETDMA
JMP BDOS

; Select the human-readable config status string.
SHOWCFGSTATUS
LDA CFGSTATUS
ORA A
JZ SCS0
CPI 1
JZ SCS1
CPI 2
JZ SCS2
CPI 3
JZ SCS3
LXI D,CFGSTAT4
JMP PRINTS
SCS0 LXI D,CFGSTAT0
JMP PRINTS
SCS1 LXI D,CFGSTAT1
JMP PRINTS
SCS2 LXI D,CFGSTAT2
JMP PRINTS
SCS3 LXI D,CFGSTAT3
JMP PRINTS

; Display TESTLEN bytes from TESTTEXT through CP/M console output.
PRINTPHRASE LDA TESTLEN
ORA A
RZ
MOV B,A
LXI H,TESTTEXT
PPLP MOV E,M
PUSH B
PUSH H
CALL PUTC
POP H
POP B
INX H
DCR B
JNZ PPLP
RET

; ---------------------------------------------------------------------------
; Z85C30 SCC CHANNEL B AND RC8660 TRANSMISSION
; ---------------------------------------------------------------------------

; Initialize SCC-B.
;
; SCCDATA is a sequence of seven Z85C30 register/value pairs.  Writing a
; register number to the SCC control port selects a write register; the next
; byte programs that register.  These values are the tested Serial I/O V3
; configuration used by this utility for 19200 baud, 8 data bits, no parity,
; one stop bit.
;
; Keeping the values in a table makes the initialization compact and avoids
; duplicating a long series of OUT instructions.
SCCINITB LXI H,SCCDATA
MVI B,14                         ; Seven register/value pairs = 14 bytes
SCCLP MOV A,M
OUT BCTL
INX H
DCR B
JNZ SCCLP

; Send a CR after initialization so the RC8660 input parser starts cleanly.
MVI C,CR
CALL TXCHAR
RET

; Z85C30 write-register/value pairs.
SCCDATA DB 04H,44H               ; WR4
DB 03H,0C1H                      ; WR3
DB 05H,0EAH                      ; WR5
DB 0BH,56H                       ; WR11
DB 0CH,06H                       ; WR12 - baud-rate generator low byte
DB 0DH,00H                       ; WR13 - baud-rate generator high byte
DB 0EH,01H                       ; WR14 - enable baud-rate generator

; SENDCMD
;   Input: A = numeric value (0-99)
;          C = RC8660 parameter command letter
;
; Transmits: CTRL-A, decimal value, command letter, CR.
;
; B and D are preserved because callers often hold useful state there.
SENDCMD PUSH B
PUSH D
MOV D,C                          ; Save command letter
MOV E,A                          ; Save numeric value
MVI C,CTRLA
CALL TXCHAR
MOV A,E
CALL SENDDEC
MOV C,D
CALL TXCHAR
MVI C,CR
CALL TXCHAR
POP D
POP B
RET

; Convert A (0-99) to one or two ASCII decimal digits and transmit them.
; Repeated subtraction is small and perfectly adequate for this range.
SENDDEC PUSH B
MOV B,A
CPI 10
JC SDONE1
MVI C,'0'
SDTEN MOV A,B
CPI 10
JC SDTEND
SUI 10
MOV B,A
INR C
JMP SDTEN
SDTEND CALL TXCHAR
SDONE1 MOV A,B
ADI '0'
MOV C,A
CALL TXCHAR
POP B
RET

; TXCHAR
;   Input: C = byte to transmit through SCC-B
;   Output: CY=0 transmitted
;           CY=1 timeout waiting for transmitter
;
; Z85C30 RR0 bit 2 is "transmit buffer empty".  The 16-bit HL countdown keeps
; a missing/misconfigured SCC from hanging VOICE.COM forever.
TXCHAR PUSH PSW
PUSH D
PUSH H
MOV E,C
LXI H,0FFFFH
TXWAIT IN BCTL
ANI 04H
JNZ TXGO
DCX H
MOV A,H
ORA L
JNZ TXWAIT
POP H
POP D
POP PSW
STC
RET

TXGO MOV A,E
OUT BDTA
POP H
POP D
POP PSW
ORA A                             ; Clear carry
RET

; Send the current persistent test phrase to the speech module.
SAYTEST LDA TESTLEN
ORA A
JZ SAYEND
MOV B,A
LXI H,TESTTEXT
STLOOP MOV C,M
PUSH B
PUSH H
CALL TXCHAR
POP H
POP B
INX H
DCR B
JNZ STLOOP
JMP SAYEND

; Send the fixed, zero-terminated short phrase used after parameter changes.
SAYSHORT LXI H,SHORTMSG
SAYZ MOV A,M
ORA A
JZ SAYEND
MOV C,A
CALL TXCHAR
INX H
JMP SAYZ

; RC8660 text is terminated with CR, which tells it to process/speak the text.
SAYEND MVI C,CR
JMP TXCHAR

; ---------------------------------------------------------------------------
; CONSOLE INPUT / OUTPUT HELPERS
; ---------------------------------------------------------------------------

; READNUM
;   Input: B = largest legal value
;   Output on success: A = parsed value, CY=0
;   Output on failure: CY=1
;
; NUMBUF is a CP/M BDOS function-10 buffer limited to two typed characters,
; which is enough for every numeric parameter in this utility.
READNUM PUSH B
LXI D,NUMBUF
MVI C,10
CALL BDOS
CALL CRLF
POP B

; Reject empty input and anything longer than two digits.
LDA NUMBUF+1
ORA A
JZ RNFAIL
CPI 3
JNC RNFAIL

MOV C,A                          ; C = number of characters to parse
LXI H,NUMBUF+2
MVI E,0                          ; E = accumulated value

; Parse decimal by repeatedly computing E = E*10 + digit.
RNLOOP MOV A,M
CPI '0'
JC RNFAIL
CPI ':'
JNC RNFAIL
SUI '0'
MOV D,A                          ; D = current digit

; Multiply old E by ten using shifts/adds, avoiding a multiply routine.
MOV A,E
ADD A
MOV E,A                          ; 2*E
ADD A
ADD A                            ; 8*E
MOV A,E                          ; back to 2*E
ADD A
ADD A                            ; 8*E
ADD E                            ; 10*E
ADD D                            ; 10*E + digit
MOV E,A

INX H
DCR C
JNZ RNLOOP

; Validate against caller's maximum in B.
MOV A,B
CMP E
JC RNFAIL
MOV A,E
ORA A                             ; Clear carry
RET

RNFAIL STC
RET

; Print a CP/M '$'-terminated string at DE.
PRINTS MVI C,9
JMP BDOS

; Print character E through CP/M console output.
PUTC MVI C,2
JMP BDOS

CRLF MVI E,CR
CALL PUTC
MVI E,LF
JMP PUTC

WAITKEY LXI D,KEYMSG
CALL PRINTS
MVI C,1
CALL BDOS
CALL CRLF
RET

; Convert ASCII a-z in A to A-Z.  Other characters are returned unchanged.
UPPER CPI 'a'
RC
CPI '{'
RNC
SUI 20H
RET

; Print unsigned A (0-99) in decimal through CP/M console output.
PRINTDEC PUSH B
MOV B,A
CPI 10
JC PDONES
MVI C,'0'
PDTEN MOV A,B
CPI 10
JC PDTEND
SUI 10
MOV B,A
INR C
JMP PDTEN
PDTEND MOV E,C
CALL PUTC
PDONES MOV A,B
ADI '0'
MOV E,A
CALL PUTC
POP B
RET

; Map CURVOICE 0-10 to its display name.  Because range validation occurs at
; input/load time, anything >=10 naturally falls through to Gretchen (10).
PRINTVNAME LDA CURVOICE
ORA A
JZ VN0
CPI 1
JZ VN1
CPI 2
JZ VN2
CPI 3
JZ VN3
CPI 4
JZ VN4
CPI 5
JZ VN5
CPI 6
JZ VN6
CPI 7
JZ VN7
CPI 8
JZ VN8
CPI 9
JZ VN9
LXI D,VN10S
JMP PRINTS
VN0 LXI D,VN0S
JMP PRINTS
VN1 LXI D,VN1S
JMP PRINTS
VN2 LXI D,VN2S
JMP PRINTS
VN3 LXI D,VN3S
JMP PRINTS
VN4 LXI D,VN4S
JMP PRINTS
VN5 LXI D,VN5S
JMP PRINTS
VN6 LXI D,VN6S
JMP PRINTS
VN7 LXI D,VN7S
JMP PRINTS
VN8 LXI D,VN8S
JMP PRINTS
VN9 LXI D,VN9S
JMP PRINTS

; ---------------------------------------------------------------------------
; WORKING STATE AND DISPLAY STRINGS
; ---------------------------------------------------------------------------

; Current settings held in RAM.
CURVOICE DB 0
CURVOL DB 5
CURPITCH DB 50
CURTONE DB 1
CURSPEED DB 5
CUREXPR DB 5
CURART DB 5
CURFORM DB 50
CURREVERB DB 0

KNOWNMASK DB 0FFH                ; Explicit-parameter bits; see header
CFGSTATUS DB 0                   ; Config-file state; see header
TESTLEN DB 0
TESTTEXT DS 76                   ; Persistent test phrase, not terminated

; ANSI screen clear + cursor home, terminated for BDOS function 9.
CLEARSTR DB ESC,'[2J',ESC,'[H','$'

BANNER DB 'IMSAI 8080  -  V-STAMP VOICE LAB  V1.2',CR,LF
DB 'S-100 Serial I/O V3 / RC8660 / SCC-B A0/A2 @ 19200 8N1',CR,LF
DB '------------------------------------------------------------',CR,LF,'$'

LVOICE DB 'Voice preset : $'
LVOL DB 'Volume       : $'
LPITCH DB 'Pitch        : $'
LTONE DB 'Tone         : $'
LSPEED DB 'Speed        : $'
LEXPR DB 'Expression   : $'
LART DB 'Articulation : $'
LFORM DB 'Formant      : $'
LREVERB DB 'Reverb       : $'
LCONFIG DB 'Config       : $'
LPHRASE DB 'Test phrase  : $'
PHRASEIND DB '  $'
PRESET DB '(preset)$'
BASS DB 'Bass$'
NORMAL DB 'Normal$'
TREBLE DB 'Treble$'

MENU DB CR,LF
DB 'V=select voice   N=next voice     L=volume 0-9',CR,LF
DB 'P=pitch 0-99     T=tone 0-2       S=speed 0-13',CR,LF
DB 'E=expression 0-9 A=articulation   F=formant 0-99',CR,LF
DB 'R=reverb 0-9     C=set test phrase W=save configuration',CR,LF
DB 'D=factory defaults SPACE=test phrase Q=quit',CR,LF,CR,LF
DB 'Command: $'

PROMPTVOICE DB 'Voice number 0-10: $'
PROMPTVOL DB 'Volume 0-9: $'
PROMPTPITCH DB 'Pitch 0-99: $'
PROMPTTONE DB 'Tone 0=Bass, 1=Normal, 2=Treble: $'
PROMPTSPEED DB 'Speed 0-13 (0 slowest, 13 fastest): $'
PROMPTEXPR DB 'Expression 0-9 (0 monotone, 9 animated): $'
PROMPTART DB 'Articulation 0-9 (low slurred, high clipped): $'
PROMPTFORM DB 'Formant 0-99: $'
PROMPTREVERB DB 'Reverb 0-9: $'
PROMPTTEXT DB 'New persistent test phrase (up to 76 chars): $'

BADMSG DB 'Invalid value.',CR,LF,'$'
KEYMSG DB 'Press any key...$'
EXITMSG DB CR,LF,'VOICE.COM finished.',CR,LF,'$'
SAVEERR DB 'Unable to write VOICE.CFG.',CR,LF,'$'

CFGSTAT0 DB 'Factory defaults (no VOICE.CFG)$'
CFGSTAT1 DB 'VOICE.CFG loaded/saved$'
CFGSTAT2 DB 'Modified - press W to save$'
CFGSTAT3 DB 'SAVE FAILED$'
CFGSTAT4 DB 'Invalid VOICE.CFG - using factory defaults$'

; RC8660 preset names.
VN0S DB 'Perfect Paul$'
VN1S DB 'Vader$'
VN2S DB 'Big Bob$'
VN3S DB 'Precise Pete$'
VN4S DB 'Ricochet Randy$'
VN5S DB 'Biff$'
VN6S DB 'Skip$'
VN7S DB 'Robo Robert$'
VN8S DB 'Goliath$'
VN9S DB 'Alvin$'
VN10S DB 'Gretchen$'

; Built-in speech samples.
DEFAULTMSG DB 'Hello. I am your IMSAI 8080. Shall we play a game?'
DEFAULTEND EQU $
SHORTMSG DB 'IMSAI speech test.',0

; ---------------------------------------------------------------------------
; CP/M BUFFERS AND STACK
; ---------------------------------------------------------------------------

; FCB template for VOICE.CFG.  Drive byte 0 means "current drive".
; The 24 zero bytes complete the standard 36-byte CP/M 2.x FCB.
CFGFCBT DB 0,'VOICE   ','CFG'
DS 24
CFGFCB DS 36

; One complete CP/M disk record for VOICE.CFG.
CFGBUF DS 128

; BDOS function-10 input buffers.
; NUMBUF: maximum 2 characters + returned count + character storage.
NUMBUF DB 2,0
DS 3

; TEXTBUF: maximum 76 characters + returned count + character storage.
TEXTBUF DB 76,0
DS 77

; Private stack space.  The program sets SP to the end of this area so the
; stack grows downward through these 64 bytes.
DS 64
STACKTOP EQU $

END START
