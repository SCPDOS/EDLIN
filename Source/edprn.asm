;---------------------
; Print Routines here
;---------------------
printString:
    mov eax, 0900h
    int 21h
    return
;----------------------------------------
; These functions print individual chars
;----------------------------------------
printSpace:
    mov al, SPC
    jmp short printChar
printCRLF:
;Prints CRLF
    mov al, CR
    call printChar
printLF:
    mov al, LF
printChar:
;Input: al = Char to print
    push rax    ;To preserve the rest of eax
    push rdx
    movzx edx, al
    mov eax, 0200h
    int 21h
    pop rdx
    pop rax
    return

;------------------------------------------------
; These functions are specialised print routines
;------------------------------------------------
printLineNum:
;Prints the line number in bx
;Input: bx = Line number to print
    call printSpace
    call printNum
    mov al, ":"
    call printChar
    cmp bx, word [curLineNum]
    mov al, SPC
    jne printChar
    mov al, "*"
    jmp short printChar

printNum:
;Takes in bx a binary word and prints the ASCII value
; with leading blanks suppressed.
;Trashes eax, ecx and edx only
    push rbp
    xor ebp, ebp    ;If not zero, stop suppressing leading zeros
    movzx edx, bx   ;Init with value in edx
;Do 10000's
    mov ecx, 10000
    call .doCompute
;Do 1000's
    mov ecx, 1000
    call .doCompute
;Do 100's
    mov ecx, 100
    call .doCompute
;Do 10's
    mov ecx, 10
    call .doCompute
;Do 1's, mild optimisation to avoid div move the remainder directly
    mov eax, edx    ;Remainder in edx
    call .printDig  ;Print the value in eax
;Exit
    pop rbp
    return
.doCompute:
;Input: ecx = Divisor for place value
;       edx = Remainder left to divide
    mov eax, edx    ;Moves the prev. remainder into eax for dividing
    xor edx, edx    
    div ecx         
.printDig:
;Now print the digit in al, the quotient. edx has the remainder
    test ebp, ebp
    jnz .pDigOk
    test eax, eax   ;Is ebp = 0 and value to print 0? 
    jz printSpace   ;If so, print a space char (retz for no suppression)
    dec ebp         ;Else, now set ebp and print al
.pDigOk:
    add al, "0"     ;Convert into an ASCII value
    jmp short printChar   ;Return through printchar

printLine:
;Prints a single line
    mov edi, 1  ;Print a single line
printLines:
;Prints many lines in EDLIN fashion. All regs trashed.
;Input:
;   bx = Line number offset to keep track of printing
;   rsi -> Ptr to start printing from
;   edi = Number of lines to print. Used as a word!
;Output:
;   bx = Last line number printed
    mov rcx, qword [eofPtr]
    sub rcx, rsi
    retz    ;If we are pointing to the eofPtr, nothing to print, return
    ;Now ecx = Number of chars to print!
;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
; Get screen attribs here for controlled printing
    mov edx, edi    ;Save number of lines to print in edx
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
.freshLine:
    push rcx
    push rdx
    call printLineNum   ;Save ecx and edx as these are trashed!
    pop rdx
    pop rcx
    lea rdi, spareLine
.goLine:
;Now we read the line into the spare buffer and echo each char one by one
;ecx = Number of chars to print
;edx = Number of lines we are printing
    lodsb
    push rbp
    lea rbp, spareLine + 254
    cmp rdi, rbp
    pop rbp
    jae .goDone
    cmp al, SPC
    jae .store  ;If a normal char print it
    ;Pick off LF, CR and TAB as special chars. Everything else is a ctrl char!
    cmp al, LF 
    je .store
    cmp al, CR
    je .store
    cmp al, TAB
    je .store
    mov ah, "^"
    or al, 40h  ;Convert to UC
    xchg al, ah
    stosw   ;Store the pair of chars
    jmp short .goDone
.store:
    stosb
.goDone:
    cmp al, LF  ;If not a line feed yet, keep going
    je .lfFnd   ;Else, we are done!
    dec ecx     ;One less char to deal with
    jnz .goLine
.lfFnd:
    dec ecx     ;Drop the final char on the line too!
    cmp byte [rdi - 1], LF  ;Was the last char a LF?
    je .okLine
    cmp byte [rdi - 1], CR  ;Was the last char a CR?
    je .putLF
    mov al, CR
    stosb
.putLF:
    mov al, LF
    stosb
.okLine:
    mov byte [rdi], 0   ;Null terminate the line for printing
    call prnAsciiz  ;Print the chars in the buffer
    jecxz .exit     ;If we have no more chars to print, exit!
    inc ebx         ;Goto next line number
    dec edx         ;One less line to print!
    jnz .freshLine  ;If this is non-zero, keep going!
    dec ebx         ;We done the last line
.exit:
    return

prnAsciiz:
    push rsi
    lea rsi, spareLine  ;Now print the line we just made!
.pcLp:
    lodsb
    test al, al
    jz .pcExit
    call printChar  ;Preserves dx
    jmp short .pcLp
.pcExit:
    pop rsi
    return