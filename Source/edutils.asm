;Utility functions for edlin go here

strlen:
;String length based on terminator in al
;Input: rsi -> Source Ptr
;       al = Terminating char to search for
;Output: ecx = Number of chars i nstring including terminator
    xor ecx, ecx
    dec ecx
    push rdi
    mov rdi, rsi
    repne scasb
    pop rdi
    neg ecx ;Take 2's compliment to get number of chars including terminator
    return

strcpy:
;Copies a string from one buffer to another
;Input: rsi -> Source Ptr
;       rdi -> Destination Ptr
    push rsi
    push rdi
    push rcx
    mov ecx, lineLen    ;Max number of chars in a string
.lp:
    call isCharEOL
    je short .exit
    movsb   ;Move the char over, inc both pointers
    dec ecx
    jnz short .lp
.exit:
    pop rcx
    pop rdi
    pop rsi
    return

memmove:
;Copies a number of bytes over from one buffer to another
;Input: rsi -> Source Ptr
;       rdi -> Destination Ptr
;       ecx = Count of chars to copy
    push rsi
    push rdi
    push rcx
    rep movsb
    pop rcx
    pop rdi
    pop rsi
    return

memset:
;Initialises a buffer to contain a particular value
;Input: rdi -> Buffer to set to given value
;       al = Value to set the buffer to
;       rcx = Number of bytes in buffer
    push rcx
    push rdi
    rep stosb
    pop rdi
    pop rcx
    return

findLineEnd:
;Returns in rsi a pointer to the end of the line
;Input: rsi -> Start of the line find the end of
;Output: rsi -> Last char in the string (NOTE: LAST CHAR NOT PAST)
;Trashes: rcx
    mov ecx, lineLen
.lp:
    call isCharEOL  ;If ZF=ZE, then rsi points to EOL
    rete
    dec ecx
    retz    ;If ecx is now 0, means rsi points to the end of line (NO EOL CHAR)
    inc rsi
    jmp short .lp

isCharEOL:
;Input: rsi -> Char/Word to analyse
;Output: ZF=ZE if char/word at rsi LF or CR,LF.
;        ZF=NZ if not
    call isCharEOF
    rete
    cmp byte [rsi], LF
    rete
    cmp byte [rsi], CR
    retne
    cmp byte [rsi + 1], LF
    return

isCharEOF:
;Input: rsi -> Char to check if it is ^Z
;Output: ZF=ZE if char at rsi is ^Z AND we are checking for EOFs
;        ZF=NZ if char at rsi is not ^Z or we are not checking for eof's
    push rax
    mov al, byte [noEofCheck]
    not al  ;Invert the bits (1's compliment)
    pop rax
    retnz   ;Return if not checking for EOF
    cmp byte [rsi], EOF ;Check if eof
    return

