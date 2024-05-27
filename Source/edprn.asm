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
