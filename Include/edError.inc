;Edlin specific errors

errOk       equ 0
errBadRen   equ 1   ;Couldn't rename files.
errDskFull  equ 2   ;Disk full.
errBadRead  equ 3   ;Couldn't move file pointer or read file in append
errBadBak   equ 4   ;Couldn't delete backup file