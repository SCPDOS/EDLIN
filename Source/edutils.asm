;Utility functions for edlin go here

strlen:
;String length based on terminator in al
;Input: rsi -> Source Ptr
;       al = Terminating char to search for
;Output: ecx = Number of chars instring including terminator
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

strcpyASCIIZ:
;Copies a ASCIIZ string from one buffer to another. 
;Pointers don't move.
;Input: rsi -> Source Ptr
;       rdi -> Destination Ptr
    push rsi
    push rdi
.cpChar:
    lodsb
    stosb
    test al, al ;Was this a nul char?
    jnz .cpChar
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


asciiToFCB:
;Converts a filename in the form FILENAME.EXT,0 to FILENAMEEXT
;Will uppercase any lowercase chars as this could be used with user buffers.
;Names such as SYS.COM get converted to "SYS     COM"
;Name is space padded.
;Input: rsi = ASCII string buffer
;       rdi = FCB name buffer
;Output: al = Char that terminated the source string 
    push rbx    
    push rdi
    mov ecx, 11
    mov al, " "
    rep stosb   ;Fill the buffer with spaces (so we don't need to fill later)
    pop rdi
    mov rbx, rdi    ;Use rbx as the base pointer of this buffer
.processName:
    lodsb   ;Get the char in al
    test al, al
    jz .exit
    cmp al, " " ;If space or a period, go to extension field. If null, exit
    je .extSpace
    cmp al, "."
    je .ext
    stosb   ;Store the char
    jmp short .processName
.extSpace:
;Now we scan for a period in the name
    lodsb   ;Get a char and increase rsi
    test al, al
    jz .exit
    cmp al, "."     ;If al is not a period...
    jne .extSpace   ; keep searching
.ext:
    lea rdi, qword [rbx + filename.fExt]    ;Put destination at the extension
.processExt:
    lodsb
    test al, al
    jz .exit
    cmp al, " "
    je .exit
    stosb
    jmp short .processExt
.exitBadChar:
    xor al, al  ;Return a null terminator
.exit:
    pop rbx
    return

FCBToAsciiz:
;Converts a filename in the form FILENAMEEXT to FILENAME.EXT,0
;Name is space padded too
;Input: rsi = FCB name buffer
;       rdi = ASCIIZ string buffer
    mov ecx, 8
    rep movsb   ;Move the name over
.scanNameSpace:
    cmp byte [rdi - 1], " " ;Is the previous char a space?
    jne .ext
    dec rdi
    inc ecx
    cmp ecx, 8
    jb .scanNameSpace
.ext:
    cmp word [rsi], "  "    ;Are the first two chars a space?
    jne .validExt
    cmp byte [rsi + 2], " " ;Is the final char a space?
    je .exit
.validExt:
    mov al, "." ;We have a valid extension, store a period
    stosb
    mov ecx, 3
    rep movsb   ;Move the three extension chars over
.scanExtSpace:
    cmp byte [rdi - 1], " " ;Is the previous char a space
    jne .exit
    dec rdi
    jmp short .scanExtSpace
.exit:
    xor eax, eax
    stosb   ;Store a null at the end
    return
