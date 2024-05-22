;Utility functions for edlin go here

printString:
    mov eax, 0900h
    int 21h
    return
printMemErr:
    lea rdx, badMemSize
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
;Input: ebx = Line number to search for, 0 means exhaust all chars!
;Output: ZF=ZE: rdi -> Ptr to the line
;               ebx = Actual line number we are at
;               eax = Line number specified
;        ZF=NZ: Line not found. (i.e. beyond last line)
    movzx edx, word [curLineNum]    ;Line to start counting from
    mov rdi, qword [curLinePtr]     ;Pointer to this line
    cmp ebx, edx
    rete    ;If we are already at the line we want to be at, return!
    ja .prepSearch  
    test ebx, ebx   ;Are we in the goto last line case?
    jz .prepSearch
;Else, we start scanning from the start of the arena!
    mov edx, 1
    mov rdi, qword [memPtr] 
    cmp ebx, edx
    rete    ;If we want to find line 1, here we are!
.prepSearch:
    mov rcx, qword [eofPtr]
    sub rcx, rdi    ;Turn ecx into count of chars left in buffer to scan
findLineCore:
;Finds a line but from a presetup position as opposed to the global state!
;Input: rdi -> Line to check if it is terminated by a LF
;       ecx = Number of chars to check on
;       edx = Offset of line count to search for (line counter)
;       ebx = Count of lines to search for (0 means exhaust chars)
;Output:
;       al = LF
;       ZF=ZE: We read bx lines. rdi -> Past LF which terminated line
;       ZF=NZ: Ran out of chars
    mov eax, LF
.lp:
    jecxz .exit ;Return w/o setting flags if we have no more chars left!
    repne scasb
    inc edx
    cmp edx, ebx    ;Have we gone past bx lines yet?
    jne .lp    ;Scan the next line if not!!
.exit:
    return

delBak:
;Deletes the backup file! Callable once only!
    test byte [bakDel], -1
    retnz
    mov byte [bakDel], -1   ;No longer callable


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
    cmp byte [rsi], LF
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

checkEOF:
;Checks if we are at the EOF or if we hit an EOF char in the file.
;Input: ecx = Count of bytes
;       rdi -> Ptr to the start of the region we just read into memory
;       r10 = Original requested byte count
;Output: ZF=ZE => Found EOF in file (or ecx = 0)
;        ZF=NZ => No EOF found in file!
;       ecx = Count of relevant bytes in the buffer
    test byte [noEofChar], -1   ;If set, binary semantics!
    jnz .binScan
;Here we scan for ^Z char
    push rdi
    push rcx
    mov eax, EOF
    test ecx, ecx   ;If ecx is 0, skip the scan! Pretend we hit an EOF
    jz .ascNoEof
    repne scasb
    jne .ascNoEof
    pushfq
    inc ecx         ;Increment by 1 to include the ptr to the EOF char itself!
    popfq
.ascNoEof:
    mov edi, ecx    ;Save the byte count in edi (rdi)
    pop rcx         ;Get back the original byte count!
    pushfq
    sub ecx, edi    ;Get the number of chars into the string we are 
    popfq
    pop rdi
.niceExit:
    retnz               ;If we are here and ZF=NZ, exit as no EOF hit
;Now we adjust the end of the file, if the end of the file was a ^Z
; so that if the last char was not an LF, we add a CRLF pair
    pushfq
    push rdi
    add rdi, rcx    ;Go the the end of the buffer
    dec rdi
    cmp qword [memPtr], rdi ;Are we at the head of the buffer?
    je .putCRLF ;If so, forcefully place a CRLF pair
    cmp byte [rdi], LF
    je .exit
.putCRLF:
    mov word [rdi + 1], CRLF
    add ecx, 2  ;We added two chars to the count
.exit:
    pop rdi
    popfq
    return
.binScan:
;Here we deal with binary semantics
    cmp ecx, r10d   ;If we read less bytes than desired, check if an EOF present!
    jb .binLess
    xor eax, eax
    inc eax         ;Clear ZF
    return
.binLess:
    jecxz .binEofExit ;If ecx = 0, just adjust end and exit!
    cmp byte [rdi + rcx], EOF   ;Was this byte an EOF char?
    jne .binEofExit
    dec ecx             ;Drop it from the count.
.binEofExit:
    xor eax, eax
    jmp short .niceExit


markFileModified:
    mov byte [modFlag], -1
    return

getModifiedStatus:
;If returns ZF=ZE, file NOT modified.
;Else, file modified.
    test byte [modFlag], -1
    return

delBkup:
;Finally, we delete the backup if it exists. If it doesn't delete
; for some reason, might be problematic later but not a big issue.
;If returns with CF=CY, know that the backup didn't delete...
;Preserves all registers!
    test byte [bkupDel], -1     ;If set, backup already deleted
    retnz
    call getModifiedStatus   ;If clear, buffer has not been modified.
    retz                        
    test byte [newFileFlag], -1 ;If the file is new then it has no backup!
    retnz
    mov byte [bkupDel], -1      ;Now deleting backup
    push rax
    push rdx
    push rdi
    mov rdi, qword [fileExtPtr]
    mov eax, "BAK"
    stosd
    lea rdx, bkupfile
    mov eax, 4100h
    int 21h
    pop rdi
    pop rdx
    pop rax
    retnc  ;Could overwrite first byte of this function with a ret 0:)
    ;I like my idea... but no, we need the flag.
    lea rdx, badBackDel
    call printString
    retToDOS errBadBak

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
;Maximum input value per argument: 65529
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
    cmp byte [argCnt], 4    ;Argument 2 is for the count
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
    int 21h
    pop rdx
    pop rax
    return

;---------------------------------------------------------------------------
;                  !!!! IMPORTANT Int 23h HANDLER !!!!
;---------------------------------------------------------------------------
i23h:
;^C handler. Reset the stack pointer and jump to get command
    lea rsp, stackTop
    cld
    call printCRLF
    jmp getCommand  ;Now jump to get the command

;Remove before finishing!
_unimplementedFunction:
    lea rdx, .str
    mov eax, 0900h
    int 21h
    return
.str:   db CR,LF,"EXCEPTION: UNIMPLEMENTED FUNCTION CALLED",CR,LF,"$"