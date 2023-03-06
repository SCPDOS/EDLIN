;edlin structures
linelen     equ 128
maxLine     equ 65536
maxAlloc    equ maxLine*lineLength ;8Mb in size
fileRO      equ 1   ;Mask for Read Only

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

;Bona-Fida Structures

struc cmdArgs   ;Ptr returned in rdx after 41h/6101h has this structure
    .fcb1       db 16 dup (?)  ;First FCB,    argument 1 
    .fcb2       db 20 dup (?)  ;Second FCB,   argument 2
    .dta:   ;Pointer to the default DTA in the 
    .parmList   db ?   ;Number of characters in command tail
    .progTail   db 127 dup (?) ;Default DTA/Program tail
endstruc

;Memory arenas are our equivalent of the DOS Arenas.
;They can only be used to store one type of information though.
struc memArena
    .pMemArena  dq ?    ;Pointer to the next arena
    .dCount     dd ?    ;Count of objects in this arena
    .dMaxAlloc  dd ?    ;How many objects can we save in this arena
    .bFlags     db ?    ;Flags for the memoryArena
                db 3 dup(?) ;Padding
    .memoryArena:       ;Symbol to the start of the space
endstruc

maxArenaNumber  equ 20  ;A maximum of 20 arenas only
arenaSize       equ 10000h  ;Number of paragraphs (1Mb)

struc line
    .dNumber    dd ?    ;Capped by maxLine
    .bFlags     db ?    ;Flags, status of line
    .pLine      dq ?    ;Pointer to the next line, 0 for last line
    .pStrHead   dq ?    ;Pointer to the string head
    .pMemArena  dq ?    ;Pointer to the memory arena we are in
endstruc
lineFlagRef     equ 1h  ;Referenced, i.e. line in use
lineFlagDirty   equ 2h  ;Dirty, data in this line needs to be flushed


;Strings are always stored consecutively and so arenas of strings
; are walked as arrays
struc string
    .bFlags     db ?    ;Set to -1 if in use, 0 if free
    .pMemArena  dq ?    ;Pointer to the memory arena we are in
    .bLength    db ?    ;String length, computed on edit commit
    .sHead      db linelen db (?)   ;Each string is of maximum length
endstruc

strFree     equ 00h
strInUse    equ 0FFh