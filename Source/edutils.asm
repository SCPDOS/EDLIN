;Utility functions for edlin go here


checkArgOrder:
;Checks two arguments to ensure the second one is 
; greater than the first.
;Input: eax = first argument
;       ebx = second argument
;Output: If it returns, its ok. Else it resets the command loop
    cmp ebx, 0
    retz
    cmp ebx, eax
    reta
    jmp printComErr

findLine:
;Given a line number, tries to find the actual line.
;Works by checking for LF chars or CR, LF pairs. If a EOF char 
; encountered, and EOF check turned off, it is ignored. Else, return
; "line not found". Both 0 and 1 refer to the first line.
;Input: eax = Line number
;Output: CF=NC: rdi -> Ptr to the line
;        CF=CY: Line not found. (i.e. beyond last line)
    push rax
    push rcx
    push rdx
    push rsi
    mov edx, eax
    mov rsi, qword [memPtr] ;Get the mem pointer
    mov ecx, dword [textLen]    ;Number of chars in the arena
.lp:
    lodsb   ;Get the current byte
    dec ecx ;One less char left
    cmp al, LF
    je short .lf
    cmp al, CR
    je short .lp
    cmp al, EOF
    je short .eof
    test ecx, ecx   ;No chars left to read in the arena?
    jnz short .lp
.bad:
    stc
    jmp short .exit
.eof:
    test byte [noEofChar], -1
    jnz short .lp
    jmp short .bad
.lf:
    dec edx ;Decrement the number of lines we have left to search for
    jnz short .lp
    mov rdi, rsi    ;rsi points to the char after lf
.exit:
    pop rsi
    pop rdx
    pop rcx
    pop rax
    return

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

markFileModified:
    mov byte [modFlag], -1
    return

getModifiedStatus:
;If returns ZF=ZE, file NOT modified.
;Else, file modified.
    test byte [modFlag], -1
    return

appendEOF:
;If no EOF char found and we are at the EOF, add one!
    test byte [newFileFlag], -1 ;New files always have their EOF loaded
    jnz short .newFile
    test byte [eofReached], -1  ;Only append an EOF if we reached the og EOF
    retz
    test byte [noEofChar], -1   ;If set, we ignore all embedded EOF chars
    jnz short .searchAway
.newFile:
    call searchTextForEOFChar
    retz    ;If ZF=ZE, exit, we are ok!
.searchAway:
    mov rdi, qword [memPtr]
    xor ecx, ecx
    mov ecx, dword [textLen]  ;Go to the end of the text
    add rdi, rcx
    mov rax, qword [endOfArena]    
    sub rax, rdi    ;If this difference is 0, exit.
    retz
    ;Else, add a single ^Z and exit
    mov byte [rdi], EOF
    inc dword [textLen]
    call markFileModified
    return

searchTextForEOFChar:
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;NOTE: THIS FUNCTION MUST NOT BE CALLED IF WE ARE TO IGNORE EOF's!
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;This function is to search for an EOF char in the text.
;If found, we check if the previous char is LF. If it isn't
; place a CR/LF with the CR on the ^Z. If no bytes left in
; arena leave the embedded ^Z in situ (boo!)
;Return: ZF=ZE -> EOF found
;        ZF=NZ -> No EOF char found
    push rax
    push rcx
    push rdi
    mov rdi, qword [memPtr]
    xor ecx, ecx
    mov ecx, dword [textLen]  ;Go to the end of the text
    jecxz .exitNotFound ;If the file has length no bytes, default
    mov al, EOF
    repne scasb ;Search the arena for a EOF char
    jz short .found ;^Z found or ecx was zero
.exit:
    pop rdi
    pop rcx
    pop rax
    return
.found:
    dec rdi ;Point rdi to the ^Z char
    cmp rdi, qword [memPtr] ;Are we the first char?
    je short .firstChar
    cmp byte [rdi - 1], LF  ;If the char before the ^Z is LF, exit ok
    je short .exit
    mov rbx, qword [endOfArena]
    sub rbx, 2  ;Make space for two more chars (the LF and new ^Z)
    cmp rdi, rbx ;If ^Z is at or near the end of the arena, do nothing
    jae short .exit2
.firstChar:
    mov byte [rdi], CR      ;Overwrite the ^Z with a CR
    mov byte [rdi + 1], LF
    mov byte [rdi + 2], EOF
    add dword [textLen], 2     ;Two more chars in text
    call markFileModified
.exit2:
    xor ecx, ecx            ;EOF char found so clear ZF
    jmp short .exit
.exitNotFound:
    xor ecx, ecx
    inc ecx ;Clear the zero flag
    jmp short .exit

delBkup:
;Finally, we delete the backup if it exists. If it doesn't delete
; for some reason, might be problematic later but not a big issue.
    test byte [bkupDel], -1     ;If set, backup already deleted
    retnz
    call getModifiedStatus   ;If clear, buffer has not been modified.
    retz                        
    test byte [newFileFlag], -1 ;If the file is new then it has no backup!
    retnz
    push rax
    push rdx
    push rdi
    mov rdi, qword [fileExtPtr]
    mov eax, "BAK"
    stosd
    lea rdx, bkupfile
    mov eax, 4100h
    int 41h
    pop rdi
    pop rdx
    pop rax
    retc    ;If CF=CY, file not deleted (including if it doesnt exists).
    mov byte [bkupDel], -1  ;Backup deleted now
    return  ;Could overwrite first byte of this function with a ret 0:)

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

parseEntry:
;Parses a single command line argument.
;. means current line
;+ means positive number offset from current line
;- means negative number offset from current line
;# means line after the last line in file ALWAYS.
; This is represented in the argument var as the 
; word 0FFFFh.
;A naked number is interpreted as a line number 
; directly.
;Maximum input value per argument: 65534
;--------------------------------------------
;Input: rsi -> String to parse
;Output: (e)bx = Value of argument
;          rsi -> First char past the end of arg
;--------------------------------------------
    call skipSpaces ;Move rsi past first non-space char and get al = First char
    cmp al, "+" ;Positive offset from current line
    je short .plus
    cmp al, "-" ;Negative offset from current line
    je short .minus
    cmp al, "." ;Current line, advance ptr to command terminator
    je short .dot
    cmp al, "#" ;Last line (-1), advance ptr to command terminator
    je short .pound
    xor ebx, ebx
    xor ecx, ecx
.getArg:
    cmp al, "0"
    jb short .endOfArg
    cmp al, "9"
    ja short .endOfArg
    cmp ebx, 0FFFFh/0Ah ;If we are gonna go above the max, fail now
    jae printComErr
    dec ecx ;Indicate we have a valid digit
    sub al, "0"
    lea ebx, dword [4*ebx + ebx]    ;5*ebx
    shl ebx, 1          ;2*5*ebx = 10*ebx
    movzx eax, al
    add ebx, eax
    lodsb   ;Get the next char
    jmp short .getArg
.endOfArg:
    test ecx, ecx
    retz    ;If no char provided, exit silently. Var already 0
    test ebx, ebx   
    jz printComErr  ;Dont allow 0 as an argument
    return
.plus:
    call .validSpecial
    call parseEntry ;Now parse the entry again
    movzx eax, word [curLineNum]
    add ebx, eax    ;Only the low word is considered!!
    return
.minus:
    call .validSpecial
    call parseEntry ;Now parse the entry again, get result in ebx
    movzx eax, word [curLineNum]
    sub eax, ebx    ;Now get the differnece and ...
    mov ebx, eax    ;save the difference in ebx
    mov eax, 1
    cmovs ebx, eax  ;If the difference is less than 0, return to line 1
    return
.dot:
    call .validSpecial
    movzx ebx, word [curLineNum]    ;Goto current line (starts from 1)
    lodsb
    return
.pound:
    call .validSpecial
    dec ebx         ;Go to last line
    lodsb
    return
.validSpecial:
;Returns if it is a valid case to do so. Else no
    cmp byte [argCnt], 4    ;Argument 4 is for the count
    je printComErr
    return

skipSpaces:
;Also skips tabs
;Input: rsi must point to the start of the data string
;Output: rsi points to the first non-space char
;           al = First non-space char
    lodsb
    cmp al, " "
    je short skipSpaces  
    cmp al, TAB
    je short skipSpaces
    return

getPtrToStr:
;Gets a pointer to the string number specified.
;Input: eax = String number to get a pointer to
;Output: rsi -> First byte of the string selected
    push rcx
    push rsi
    mov rsi, qword [memPtr] ;Get a pointer to the area to read
    
.exit:
    pop rsi
    pop rcx
    return

writeFile:
;Writes to file and shifts internal pointers correctly
;Input: ecx = Number of chars to write
;Output: CF=NC -> eax = Number of chars written
;        CF=CY -> Hard Error, assume nothing written for safety
    push rax
    push rbx
    push rdx
    mov rdx, qword [memPtr]     ;Get the ptr to the start of the text
    movzx ebx, word [writeHdl]  ;Get the write handle
    mov eax, 4000h
    int 41h
    jc short .exit
    xor edx, edx
    mov ebx, dword [textLen]    ;Get the number of chars in arena
    sub ebx, eax    ;Get the number of chars left in the arena
    cmovc ebx, edx  ;If carry set, something went wrong. Default to 0 chars 
    mov dword [textLen], ebx
.exit:
    pop rdx
    pop rbx
    pop rax
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

printComErr:
;JUMP to this procedure and it jumps back to
; the command loop resetting the stack!
    lea rdx, badInput
printErr:
    mov eax, 0900h
    int 41h
    jmp getCommand
;---------------------------------------------------------------------------
;                  !!!! IMPORTANT INT 43h HANDLER !!!!
;---------------------------------------------------------------------------
i43h:
;^C handler. Reset the stack pointer and jump to get command
    lea rsp, stackTop
    cld
    call printCRLF
    jmp getCommand  ;Now jump to get the command

;Remove before finishing!
_unimplementedFunction:
    lea rdx, .str
    mov eax, 0900h
    int 41h
    return
.str:   db CR,LF,"EXCEPTION: UNIMPLEMENTED FUNCTION CALLED",CR,LF,"$"