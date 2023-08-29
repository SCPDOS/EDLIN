;Structures and equates coming from DOS

;MISC ASCII control chars
NUL equ 00h ;^@         | ASCII Null
ETX equ 03h ;^C         | ASCII Break (End of Text)
ACK equ 06h ;^F         | ASCII Acknowledgement
BEL equ 07h ;^G         | ASCII Bell
BSP equ 08h ;^H         | ASCII Backspace
TAB equ 09h ;^I         | ASCII Horizontal Tab
LF  equ 0Ah ;^J         | ASCII Line Feed
CR  equ 0Dh ;^M         | ASCII Carriage Return
DLE equ 10h ;^P         | ASCII Data Link End (Toggle Print Echo)
DC3 equ 13h ;^S         | ASCII Device Control 3 (Toggle Scroll Lock)
DC4 equ 14h ;^T         | ASCII Device Control 4
NAK equ 15h ;^U         | ASCII Negative Acknowledgement
ETB equ 17h ;^W         | ASCII End of Transmission Block
EOF equ 1Ah ;^Z         | ASCII Substitute character (End of File)
ESC equ 1Bh ;           | ASCII Escape char, used for ANSI.SYS
SPC equ 20h ;Printable  | ASCII Space
;This last one is NEVER printed with a caret as it is a console control char
DEL equ 7Fh ;^?         | ASCII Rubout (Del char and dec cursor)

asciiCaret  equ 20h ;Used to check which chars need to be printed with caret
;Extended Ascii Codes
eF1     equ 3Bh ;F1 second byte
eF2     equ 3Ch ;F2 second byte
eF3     equ 3Dh ;F3 second byte
eF4     equ 3Eh ;F4 second byte
eF5     equ 3Fh ;F5 second byte
eF6     equ 40h ;F6 second byte
eF7     equ 41h ;F7 second byte
eCursL  equ 4Bh ;Cursor Left second byte
eCursR  equ 4Dh ;Cursor Right second byte
eIns    equ 52h ;Insert second byte
eDel    equ 53h ;DEL second byte (not necessarily delete key)

;Directory attribute equates
    dirReadOnly     equ 01h
    dirHidden       equ 02h
    dirSystem       equ 04h
    dirVolumeID     equ 08h
    dirDirectory    equ 10h
    dirArchive      equ 20h
    dirCharDev      equ 40h ;Never written to disk, used to represent a Char Dev
    dirLongName     equ dirReadOnly | dirHidden | dirSystem | dirVolumeID
    ;If any of the three bits are set, then ALL three bits are set
    ; in addition to whatever the user passed to search for.
    dirInclusive    equ dirHidden | dirSystem | dirDirectory
    dirIncFiles     equ dirHidden | dirSystem

struc cmdArgs   ;Ptr returned in rdx after 41h/6101h has this structure
    .fcb1       db 16 dup (?)  ;First FCB,    argument 1
    .fcb2       db 20 dup (?)  ;Second FCB,   argument 2
    .dta:   ;Pointer to the default DTA in the
    .parmList   db ?   ;Number of characters in command tail
    .progTail   db 127 dup (?) ;Default DTA/Program tail
endstruc

struc ffBlock   ;The structure of the Find First structure at the DTA
    .driveNum   resb 1  ;Drive we are searching on
    .template   resb 11 ;Search template (? meaning anything)
    .attrib     resb 1  ;Search attribute
    .dirOffset  resd 1  ;32 byte entry within dir cluster
    .parDirClus resd 1  ;Parent Directory Cluster number
    .attribFnd  resb 1  ;Attrib of file found
    .fileTime   resw 1  ;File time
    .fileDate   resw 1  ;File date
    .fileSize   resd 1  ;Number of bytes
    .asciizName resb 13 ;ASCIIZ name with dot and terminating nul
endstruc