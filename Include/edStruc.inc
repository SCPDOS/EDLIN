;edlin structures
lineLen     equ 253
halflineLen equ 128
maxLine     equ 65529
maxAlloc    equ maxLine*lineLen
maxParas    equ (maxAlloc >> 4) + 1
fileRO      equ 1   ;Mask for Read Only
fileDir     equ 10h ;Mask for Directory

;Bona-Fida Structures

struc line
    .bBufLen    db ?    ;Buffer size (255)
    .bStrLen    db ?    ;Length of the string entered in buffer
    .pString    db lineLen dup (?)      ;Actual string itself
endstruc

struc halfLine
    .bBufLen    db ?    ;Buffer size (130)
    .bStrLen    db ?    ;Length of the string entered in buffer
    .pString    db halflineLen dup (?)   ;Actual string itself
endstruc

struc filename
;8.3 File name struct
    .fName  resb 8
    .fExt   resb 3
endstruc