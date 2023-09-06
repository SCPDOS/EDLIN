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

getDecimalDwordLZ:
;Use this function to replace leading 0's with spaces
; in the decimalised DWORD from the below function.
;Input: rcx = BCD packed DWORD (byte = ASCII digit)
;Output: rcx = BCD packed DORD with leading spaces
    push rax
    mov rax, rcx
    xor ecx, ecx    ;Use as a counter for how many times we roll right
.lp:
    cmp al, '0'     ;If not a zero, we are done
    jne short .swapBack
    rol rax, 8      ;Roll the upper byte low by 8 bits
    add ecx, 8      ;Increase counter by this many bits
    jmp short .lp
.swapBack:
    ror rax, cl     ;Undo the left rolls
.exit:
    mov rcx, rax
    pop rax
    return

getDecimalDword:
;Works on MAX A dword in eax
;Gets the decimalised DWORD to print in rcx (at most 8 digits)
;Input: eax = DWORD to decimalise
;Output: rcx = BCD packed DWORD (byte = ASCII digit)
    xor ecx, ecx
    xor ebp, ebp  ;Use bp as #of digits counter
    mov ebx, 0Ah  ;Divide by 10
.dwpfb0:
    inc ebp
    shl rcx, 8    ;Space for next nybble
    xor edx, edx
    div rbx
    add dl, '0'
    cmp dl, '9'
    jbe short .dwpfb1
    add dl, 'A'-'0'-10
.dwpfb1:
    mov cl, dl    ;Save remainder byte
    test rax, rax
    jnz short .dwpfb0
    return

;skipSpaces:
;Skips all the spaces in the command line
;Input: rsi -> Buffer to skip spaces on
;Output: rsi -> First non-space char on command line
;    push rax
;    push rcx
;    push rdi
;    mov rdi, rsi
;    xor ecx, ecx
;    dec ecx
;    mov eax, SPC
;    repne scasb
;    dec rdi ;Point to the first non SPC char
;    mov rsi, rdi
;    pop rdi
;    pop rcx
;    pop rax
;    return

skipSpaces:
;Also skips tabs
;Input: rsi must point to the start of the data string
;Output: rsi points to the first non-space char
    cmp byte [rsi], " "
    je short .skip    ;If equal to a space, skip it
    cmp byte [rsi], TAB
    retne   ;If not equal to a tab or space, return
.skip:
    inc rsi
    jmp short skipSpaces

parseEntry:
;Parses a numeric command line argument.
;. means current line
;+ means positive number offset from current line
;- means negative number offset from current line
;# means line after the last line in file ALWAYS.
; This is represented in the argument var as the 
; word 0FFFFh.
;A naked number is interpreted as a line number 
; directly.
;Maximum input value per argument: 65534
;The first char ONLY may contain a special 
; character. Any other char will result in 
; an error condition. 
;Maximum number of chars per argument: 6
;An argument is terminated by a "," a 
; command letter or a ?.
;++++++++++++++++++++++++++++++++++++++++++
;CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT 
;++++++++++++++++++++++++++++++++++++++++++
;If a ? is encountered, it is a terminator
; but also sets the "qmark" var to -1
; to indicate to the function that might
; use it that a qmark has been entered.
;++++++++++++++++++++++++++++++++++++++++++
;CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT 
;++++++++++++++++++++++++++++++++++++++++++
;--------------------------------------------
;Input: rdi -> Var to store the value in
;       rsi -> First char of argument
;Output: CF=NC:
;           word [rdi] = Value to be used
;           (e)ax = Value to be used
;        CF=CY:
;           Error condition, bad input at rsi
;--------------------------------------------
    call processArg

processArg:
;Processes an argument
    call readChar   ;Get the next char in al
    call isCharSpecial
    call processSpecialChar
    jc .exit
    call isCharTerminal ;al has the char we are considering
    jne short .notTerminal
    cmp al, CR
    je short .skipCmdLetter
    cmp al, ";"
    je short .skipCmdLetter
    and al, 0DFh    ;Convert to upper case
    mov byte [cmdChar], al
.skipCmdLetter:
    
.notTerminal:

.exit:
    inc byte [argCnt]
    return

processSpecialChar:
;Input: ZF=ZE => Char in al is special. Do processing
;       ZF=NZ => Char in al is not special. Exit
;Output: Appropriate flags/vars set for the char input
;       CF=NC => Continue
;       CF=CY => Argument processed, goto next command
    retne 
    push rax
    push rbx 
    push rcx
    push rdi
    lea rdi, .specialTbl
    xor ecx, ecx
    neg ecx 
    repne scasb ;Decrement ecx until we find the char in table
    neg ecx     ;Get number of chars we advanced by
    lea rdi, .specialTbl2   ;Get the function table ptr
    movzx rbx, word [rdi + 2*rcx]   ;rbx has the offset in it
    add rbx, rdi    ;Now add the offset from the base ptr to rbx
    clc
    call rbx 
    pop rdi
    pop rcx
    pop rbx
    pop rax
    return
.plus:
    mov byte [relCur], 1    ;Positive offset from curline
    return
.minus:
    mov byte [relCur], -1   ;Negative offset from curline
    return
.qmark:
    mov byte [qmarkSet], -1 ;Question mark set
    return
.dot:
    movzx eax, word [curLineNum]    ;Goto current line
    jmp short .storeLineNum
.pound:
    xor eax, eax
    dec eax                 ;Go to last line
.storeLineNum:
    lea rdi, argTbl
    movzx ecx, byte [argCnt]
    add rdi, rcx
    mov word [rdi], ax
    stc
    return
.specialTbl:
    db "+-?.#"
.specialTbl2:
    dw .plus - processSpecialChar
    dw .minus - processSpecialChar
    dw .qmark - processSpecialChar
    dw .dot - processSpecialChar
    dw .pound - processSpecialChar

isCharTerminal:
    push rcx
    push rdi
    lea rdi, cmdLetterTable
    mov ecx, cmdLetterTableL
    repne scasb ;Scan for the char
    pop rdi
    pop rcx
    return
isCharSpecial:
    cmp al, "+" ;Positive offset from current line
    rete
    cmp al, "-" ;Negative offset from current line
    rete
    cmp al, "?" ;Set qmark on (if already on, error line)
    rete
    cmp al, "." ;Current line, advance ptr to command terminator
    rete
    cmp al, "#" ;Last line (-1), advance ptr to command terminator
    return

readChar:
;Reads the next char into al and zeros the upper 7 bytes
;Also keeps track of the var.
    push rsi
    lea rsi, cmdLine
    movzx eax, byte [charInLine]    ;Get the char in the line 
    add rsi, rax    ;Move rsi to that offset
    lodsb   ;Get the char in al
    inc byte [charInLine]
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
;---------------------------------------------------------------------------
;                  !!!! IMPORTANT INT 43h HANDLER !!!!
;---------------------------------------------------------------------------
i43h:
;^C handler. Reset the stack pointer and jump to get command
    lea rsp, stackTop
    cld
    call printCRLF
    jmp getCommand  ;Now jump to get the command