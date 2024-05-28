;General Utility functions for edlin go here

replaceLine:
;Replaces a line in memory with a line in a buffer.
;Input: ecx = New line length
;       rsi -> New line source ptr
;       edx = Old line length
;       rdi -> Old line ptr
    cmp ecx, edx
    je .doCopy
    push rcx
    push rsi
    push rdi
    mov rsi, rdi
    add rsi, rdx    ;Go to the end of the old line 
    add rdi, rcx    ;Go to where the new line will end
    mov rax, qword [eofPtr]
    sub rax, rdx    ;See if we have enough space for the new line!!
    add rax, rcx
    cmp rax, qword [endOfArena]
    jae printMemErr
    xchg qword [eofPtr], rax    ;This will be the new eof
    mov rcx, rax    ;Get the old eofPtr in rcx
    sub rcx, rsi
    cmp rsi, rdi
    ja .noRevMove
    add rsi, rcx    ;Here we setup reverse copy!!
    add rdi, rcx
    std
.noRevMove:
    inc ecx         ;Add a char for the EOF itself!
    rep movsb
    cld
    pop rdi
    pop rsi
    pop rcx
    ;Now that there is space in the buffer, we can do the copy!
.doCopy:
    rep movsb
    return

stufBuf:
;Stuffs the workLine with a line of text from memory!
;Input: rsi -> Buffer to source the stuff from
;Output: Buffer stuffed. If line too long, truncated to the first 253 chars.
;       edx = Real length of line!
    lea rdi, workLine + 2   ;Go to the start of the text portion
    mov ecx, 255
    xor edx, edx            ;Use as the char counter in the buffer
.lp:
    lodsb
    stosb
    inc edx     ;Copied one more char over
    cmp al, CR  ;Was this a CR?
    je .eol     ;Exit if so
    dec ecx     ;Else decrement from buffer counter
    jnz .lp     ; and go again!
.eol:
    dec edx     ;Drop the CR from the char count
    mov byte [workLine + 1], dl ;Store the char count here
    cmp al, CR  ;Now check we are here due to having a valid EOL
    rete        ;Exit if so
    inc edx
.longLine:  ;Else scan for the EOL char
    lodsb   ;Get the next char
    inc edx ;Keep track of the real length of the line
    cmp al, CR
    jne .longLine   ;If not CR, keep searching
    dec rdi ;Go back to the last char position in the buffer
    stosb   ;Store the CR there
    return  ;We stored max count in workLine+1 earlier. We are done

doCmdChar:
;Handles command chars that are typed into the buffer. These chars are
; ^V<CHAR> where <CHAR> has to be a UC char to be treated as a command char.
;Assumes that rsi is pointing to the start of the data portion of a command line.
;Thus:  rsi -> Input buffer
;       rsi - 1 = Number of chars typed 
;       rsi - 2 = Input buffer length
    cld                         ;Ensure we are searching the right way
    push rcx
    push rsi
    push rdi
    mov rdi, rsi                ;Copy the pointer for scanning
    movzx ecx, byte [rsi - 1]   ;Get number of chars typed in to scan
.lp:
    jecxz .exit                 ;No more chars to handle, exit!
    mov eax, CMD                ;Scan for the ^V char in al
    repne scasb
    jne .exit                   ;Ran out of chars to scan, exit!
;Here rdi points to the char after the quote char.
    mov al, byte [rdi]  ;Get the quote char
    call doControl  ;Convert into a control char if appropriate
    mov byte [rdi], al  ;Write back
;Save our position and count and pull the string up.
    push rcx
    push rsi
    push rdi
    mov rsi, rdi    ;Start copying from this replaced char
    dec rdi         ;Store to the char before
    inc ecx         ;Copy over the CR too
    rep movsb
    pop rdi
    pop rsi
    pop rcx
    jecxz .exit     ;If we terminated the line with a ^V<CR>, now exit
    dec byte [rsi - 1]  ;Else drop one char from the count
    jmp short .lp   ;And keep scanning
.exit:
    pop rdi
    pop rsi
    pop rcx
    return

doControl:
;Input: al = Possible control char. This has to be an uppercase char! 
    push rax
    and al, 0E0h    ;Preserve upper three bits only (not used for chars)
    cmp al, 40h     ;Check if only the middle (UC) was set!
    pop rax
    retne
    and al, asciiMask   ;Convert into a control char
    return

checkArgOrder:
;Checks two arguments to ensure the second one is 
; greater than the first.
;Input: bx = first argument
;       word [arg2] = second argument
;Output: If it returns, its ok. Else it resets the command loop
    cmp word [arg2], 0
    rete
    cmp bx, word [arg2]
    retbe
    pop rax     ;Pop off the return address
    jmp printComErr

makeSpace:
;Makes space for a new string in the text
;Input: rdx -> Where in the arena we will move our text
;       rdi -> First byte we will be moving
;       bx = Line number we are making space for!
    mov rcx, qword [eofPtr]
    mov rsi, rcx    ;Copy in reverse, sourcing from the EOF ptr!!    
    sub rcx, rdi    ;Get the count of bytes to copy
    inc ecx         ;Including EOF
    mov rdi, rdx    
    std
    rep movsb
    cld
    xchg rsi, rdi   ;Swap the new EOF pointer and source
    inc rdi         ;Point to the first byte of made space
    mov rbp, rsi    ;Setup to fall through now
setLineVars:
;Sets the current line number, pointer and the new EOF pointer
;Input: bx = Current line number
;       rdi -> Space where this line is
;       rbp -> EOF char pointer
    mov word [curLineNum], bx
    mov qword [curLinePtr], rdi
    mov qword [eofPtr], rbp
    return

findLine:
;Given a line number, tries to find the actual line.
;Input: ebx = Line number to search for, 0 means exhaust all chars!
;Output: ZF=ZE: rdi -> Ptr to the line
;               edx = Actual line number we are at
;               eax = Line number specified
;        ZF=NZ: Line not found. (i.e. beyond last line)
;               edx = Line number past current line number
;               rdi -> End of memory space
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

strcpy:
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


delBkup:
;Finally, we delete the backup if it exists. If it doesn't delete
; for some reason, might be problematic later but not a big issue.
;If returns with CF=CY, know that the backup didn't delete...
;Preserves all registers!
    test byte [bkupDel], -1     ;If set, backup already deleted
    retnz
    test byte [modFlag], -1   ;If clear, buffer has not been modified.
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
    je .plus
    cmp al, "-" ;Negative offset from current line
    je .minus
    cmp al, "." ;Current line, advance ptr to command terminator
    je .dot
    cmp al, "#" ;Last line (-1), advance ptr to command terminator
    je .pound
    xor ebx, ebx
    xor ecx, ecx
.getArg:
    cmp al, "0"
    jb .endOfArg
    cmp al, "9"
    ja .endOfArg
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

;---------------------------------------------------------------------------
;                  !!!! IMPORTANT Int 23h HANDLERS !!!!
;---------------------------------------------------------------------------
i23hXfr:
    movzx ebx, word [xfrHdl]
    mov eax, 3E00h  ;Close the handle
    int 21h
    ;Now reset the stack and proceed as normal
i23hInsert:
;^C handler for insert!
    lea rsp, stackTop
    cld
    call printCRLF
    call insertLine.cleanInsert ;We now reset the state of the memory
    jmp nextCmd     ;Now go to the next command in the command line!

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