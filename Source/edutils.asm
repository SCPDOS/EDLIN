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
    mov al, byte [noEofChar]
    not al  ;Invert the bits (1's compliment)
    pop rax
    retnz   ;Return if not checking for EOF
    cmp byte [rsi], EOF ;Check if eof
    return

searchTextForEOFChar:
;This function is to search for an EOF char in the text.
;If found, we check if the previous char is LF. If it isn't
; place a CR/LF with the CR on the ^Z. If no bytes left in
; arena leave the embedded ^Z in situ (boo!)
;Return: ZF=ZE -> EOF found and left in situ
;        ZF=NZ -> No EOF char found
    push rax
    push rcx
    push rdi
    mov rdi, qword [memPtr]
    xor ecx, ecx
    mov ecx, dword [textLen]  ;Go to the end of the text
    mov al, EOF
    repne scasb ;Search the arena for a EOF char
    jne short .exit ;No ^Z found
    dec rdi ;Point rdi to the ^Z char
    cmp byte [rdi - 1], LF  ;If the char before the ^Z is LF, exit ok
    je short .exit
    cmp rdi, qword [endOfArena] ;If ^Z is at the end of the arena, do nothing
    je short .exit
    mov byte [rdi + 1], LF
    mov byte [rdi], CR      ;Overwrite the ^Z, so now no more ^Z
    inc qword [textLen]     ;One more char in text
    xor ecx, ecx            ;EOF char found so clear ZF
.exit:
    pop rdi
    pop rcx
    pop rax
    return

skipSpaces:
;Skips all the spaces in the command line
;Input: rsi -> Buffer to skip spaces on
;Output: rsi -> First non-space char on command line
    push rax
    push rcx
    push rdi
    mov rdi, rsi
    xor ecx, ecx
    dec ecx
    mov eax, SPC
    repne scasb
    dec rdi ;Point to the first non SPC char
    mov rsi, rdi
    pop rdi
    pop rcx
    pop rax
    return


printDecBytePrim:
;Input: rsi -> byte to decimalise 
;       ecx = 0 => Skip leading zeros, else dont skip
;Output: If we skipped leading zeros, ecx = Count of chars printed.
;        Else, ecx undefined. 
;        rsi -> byte to decimalise
    push rax
    push rdx
    push rsi
    lodsb   ;Get the byte in al
    mov ah, al
    and ah, 0F0h    ;ah has upper nybble
    and al, 0Fh     ;al has lower nybble
    mov dl, ah
    call .printNybble
    mov dl, al
    call .printNybble
.exit:
    pop rsi
    pop rdx
    pop rax
    return
.printNybble:
;dl contains the nybble to print.
;Increments ecx for each byte printed
    push rax
    push rdx
    mov dh, dl
    cmp dl, 0Ah
    jb short .pn1
    sub dl, 0Ah
    call .prn
.pn1:
    mov dl, dh
    call .prn
.rpn:
    pop rdx
    pop rax
    return
.prn:
;If ecx is zero and dl is zero print a space.
;Else, print the value in dl
    add dl, "0"
    cmp dl, "0"
    jne short .prn1
    test ecx, ecx   ;If dl = 0 and ecx != 0, skip
    jnz short .prn1
    mov dl, SPC
    dec ecx     ;Decrement to equalise below
.prn1:
    inc ecx     ;Increment the number of chars we printed
    mov al, dl
    call printChar
    return


printDecWordLZ:
;rsi points to the word to decimalise
;Prints leading zeros.
    push rsi
    push rcx
    xor ecx, ecx
    mov ecx, 1
    jmp short printDecWord.printDecCmn1
printDecByteLZ:
;rsi points to the byte to decimalise
;Prints leading zeros.
    push rsi
    push rcx
    xor ecx, ecx
    mov ecx, 1    ;Indicate we want to print leading zeros
    jmp short printDecWord.printDecCmn
printDecByte:
;rsi points to the byte to decimalise
;Does not print leading zeros.
    push rsi
    push rcx
    xor ecx, ecx
    jmp short printDecWord.printDecCmn
printDecWord:
;rsi points to the word to decimalise
;Does not print leading zeros.
    push rsi
    push rcx
    xor ecx, ecx
.printDecCmn1:
    call printDecBytePrim
    inc rsi
.printDecCmn:
    call printDecBytePrim
    pop rcx
    pop rsi
    return


printCRLF:
;Prints CRLF
    mov al, CR
    call printChar
printLF:
    mov al, LF
;Just fall into the next function
printChar:
;Input: al = Char to print
    push rax    ;To preserve the rest of eax
    push rdx
    movzx edx, al
    mov eax, 0200h
    int 41h
    pop rdx
    pop rax
    return

i43h:
;^C handler. Reset the stack pointer and jump to get command
    lea rsp, stackTop
    cld
    call printCRLF
    jmp getCommand  ;Now jump to get the command