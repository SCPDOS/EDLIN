;---------------------
; Error Routines here
;---------------------

printMemErr:
    lea rdx, badMemFull
    jmp short printErr
printComErr:
;JUMP to this procedure and it jumps back to
; the command loop resetting the stack!
    lea rdx, badInput
printErr:
    call printString
    jmp getCommand

;The below "Fail" units are a class of Edlin terminating functions
badReadFail:
    lea rdx, badRead
    call printString
    retToDOS errBadRead

fullDiskFail:
    lea rdx, badDskFull ;Write disk full error, but return to prompt
    call printString
    retToDOS errDskFull

