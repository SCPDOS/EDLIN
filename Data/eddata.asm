newFileAllocTable:
;Units of paragraphs, less than 1Mb (10000h)
    dw 8000h    ;512Kb
    dw 4000h    ;256Kb
    dw 2000h    ;128Kb
    dw 1000h    ;64Kb
    dw 800h     ;32Kb
    dw 400h     ;16Kb
    dw 200h     ;8Kb
    dw 100h     ;4Kb
    dw 80h      ;2Kb
    dw 40h      ;1Kb
    dw 20h      ;512 bytes
    dw 10h      ;256 bytes
    dw -1       ;End of table marker
