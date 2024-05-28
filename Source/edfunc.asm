;This is where the main user selectable routines are
;All arguments specified are signed words

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File editing functions
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

editLine:
;Displays a line and allows it to be edited
;--------------------------------------------
;Invoked by: [line]
;--------------------------------------------
    cmp byte [argCnt], 1
    jne printComErr
    dec qword [charPtr] ;Adjust ptr to point to the CR or ;
    movzx ebx, word [arg1]  ;Get the line number
    test ebx, ebx
    jnz .notNext
    ;If 0, means next line
    movzx ebx, word [curLineNum]    ;Get the current line number
    inc ebx ;and go to the next line
.notNext:
    call findLine   ;rdi points to the end of memory selected line
    ;If we return with ZF set, we proceed because we found the line,
    ; else we simply return!
    mov word [curLineNum], dx
    mov qword [curLinePtr], rdi
    retnz   ;If the line specified was past the end, we return now
    cmp rdi, qword [eofPtr]
    rete    ;Return if these are equal!
    mov rsi, rdi    ;Save the current line ptr on the stack
    push rsi
    call stufBuf    ;Stuff the line pointed to by rsi into the buffer
    pop rsi         ;Get back the curLinePtr in rsi
    mov dword [workLen], edx    ;Store the real length into the var
    call printLine      
    call printLineNum
    lea rdx, workLine
    mov eax, 0A00h  ;Edit magic woo
    int 21h
    call printLF
    cmp byte [rdx + 1], 0   ;If just a CR input, return with no edit!
    retz
    lea rsi, qword [rdx + 2]    ;Go to the string portion immediately
    call doCmdChar
    mov rdi, qword [curLinePtr] ;Point to the line we have edited
    movzx ecx, byte [rdx + 1]   ;Get the adjusted string length in ecx
    mov edx, dword [workLen]    ;Get the old line length in edx
    jmp replaceLine

insertLine:
;Inserts a line
;--------------------------------------------
;Invoked by: [line]I
;--------------------------------------------
    cmp byte [argCnt], 1
    jne printComErr
    lea rdx, i23hInsert ;Set to the insert handler
    mov eax, 2523h
    int 21h
    movzx ebx, word [arg1]  ;Get the line number
    test ebx, ebx
    jnz .notNext
    ;If 0, means next line
    movzx ebx, word [curLineNum]    ;Get the current line number
.notNext:
    call findLine   ;Set line number in dx and rdi -> Space in memory!
    mov ebx, edx    ;Move the actual line number into ebx
    mov rdx, qword [endOfArena]
    call makeSpace  ;Make space to insert new line!
.inLp:
    call setLineVars
    call printLineNum
    lea rdx, workLine
    mov eax, 0A00h  ;Full on edit mode
    int 21h
    call printLF
    ;Check if the first char in the buffer is a EOF
    lea rsi, qword [rdx + 2]    ;Go to the string portion immediately
    cmp byte [rsi], EOF         ;Apparent EDLIN behaviour, terminate insert so!
    je .cleanInsert
    call doCmdChar              ;Preserves rdi, the curLinePtr
    movzx ecx, byte [rsi - 1]   ;Get the number of chars typed in
    mov rdx, rdi                
    inc ecx                     ;Make space for terminating LF too
    add rdx, rcx                ;Check if we will go out of bounds
    cmp rdx, qword [endOfArena]
    jae .inBad
    cmp rdx, rbp                ;Are we past file Eof?
    jae .inBad                  ;Jump if so
    rep movsb                   ;Else copy from edit line to space made
    mov al, LF
    stosb                       ;Store the line feed too
    inc ebx                     ;Go to next line :)
    jmp short .inLp
.inBad:
    call .cleanInsert
    jmp printMemErr
.cleanInsert: 
;Move the lines after the insertion point back to where they need to be :)
    mov rsi, qword [eofPtr] 
    mov rdi, qword [curLinePtr]
    mov rcx, qword [endOfArena]
    sub rcx, rsi    ;Get the number of bytes to copy high again
    inc rsi         ;Go to char past EOF to source chars from
    rep movsb
    dec rdi         ;Go back to the EOF char itself
    mov qword [eofPtr], rdi
    lea rdx, i23h
    mov eax, 2523h  ;Set Interrupt handler for Int 23h
    int 21h
    return

deleteLines:
;Deletes one or a range of lines
;--------------------------------------------
;Invoked by: [line][,line]D
;--------------------------------------------
    cmp byte [argCnt], 2
    ja printComErr
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .notCur
    movzx ebx, word [curLineNum]
    mov word [arg1], bx ;Store it explicitly for later
.notCur:
    movzx ebx, word [arg2]
    test ebx, ebx
    jnz .goDel
    movzx ebx, word [arg1]     ;Use arg1 as the range end
    mov word [arg2], bx
.goDel:
    movzx ebx, word [arg1]
    call checkArgOrder  ;Now we check if our args are ok
    call findLine   ;If ZF=NZ, start of del not found, just return
    retnz
    push rbx    ;Save the line number
    push rdi    ;And pointer to it
    movzx ebx, word [arg2]
    inc ebx     ;Range so end at the line after
    call findLine   ;Get the end of the copy ptr
    mov rsi, rdi    ;Source chars from this line
    pop rdi
    pop rbx
    mov word [curLineNum], bx   ;Now update the line number
    mov qword [curLinePtr], rdi ;This is where we will be copying to
    mov rcx, qword [eofPtr]
    sub rcx, rsi    ;Get the number of chars to copy up
    inc ecx         ;Add one char for the eof char itself
    cld 
    rep movsb       ;Copy the whole file up
    dec rdi         ;Point to the EOF char itself
    mov qword [eofPtr], rdi
    return


transferLines:
;Writes the lines specified to the specified file
;--------------------------------------------
;Invoked by: [line]T[d:]filename
;--------------------------------------------
    cmp byte [argCnt], 1
    jne printComErr
    call skipSpaces ;Move rsi to the first char of the xfrspec
    dec rsi         ;Go to the first char
    lea rdx, xfrName
    mov rdi, rdx
.nameCp:
    lodsb
    cmp al, SPC
    je .cpOk
    cmp al, TAB
    je .cpOk
    cmp al, CR
    je .cpOk
    cmp al, ";"
    je .cpOk
    stosb
    jmp short .nameCp
.cpOk:
    mov byte [rdi], 0   ;Store terminating null
    dec rsi             ;Now go to the char which terminated the copy
    mov qword [charPtr], rsi    ;And store this as the new continuation ptr
    mov eax, 3D00h      ;Open file pointed to by rdx for reading
    int 21h
    jnc .fileOpen
    cmp ax, errFnf
    lea rdx, badFindStr ;String for if the file is not found
    lea rbx, badDrvStr  ;Else just say drive or fnf!
    cmovne rdx, rbx
    jmp printErr    ;Print the string in rdx
.fileOpen:
    mov word [xfrHdl], ax   ;Save the handle
    ;Transfer lines works like insert lines, in that it is inserting lines
    ; but from a separate file. We therefore set up a custom ^C handler 
    ; and cleanup like insert if it is invoked!
    mov eax, 2523h  ;Setup int 23h for xfr
    lea rdx, i23hXfr
    int 21h
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .notCur
    movzx ebx, word [curLineNum]    ;Get the current line number ptr
.notCur:
    call findLine   ;Get actual line number in dx, and ptr in rdi
    mov ebx, edx
    mov rdx, qword [endOfArena]     ;Copy to the end of the arena
    call makeSpace  ;And jiggle it over
    mov rdx, qword [curLinePtr] ;Read data into here now
    mov rcx, qword [eofPtr]
    sub ecx, edx    ;Get the number of chars of space we have to read in
    push rcx
    mov eax, 3F00h
    movzx ebx, word [xfrHdl]
    int 21h
    pop rdx     ;Get the count back into rdx
    mov ecx, eax    ;Move the count into ecx
    cmp edx, eax
    ja .fullXfr
    ;We copied exactly the size of the arena, assume this means the whole 
    ; file may not have been copied. We still proceed though
    lea rdx, badMergeStr
    mov rcx, qword [curLinePtr]
    jmp .endXfr
.fullXfr:
    add rcx, qword [curLinePtr] ;Turn into offset from start of line
    mov rsi, rcx
    dec rsi ;Go to the last char we read in
    lodsb
    cmp al, EOF
    jne .endXfr
    dec rcx ;Drop a byte
.endXfr:
    mov rdi, rcx        ;Copy to the curLinePtr pos
    mov rsi, qword [eofPtr]
    inc rsi             ;Start copying from the stored data past the eofPtr
    mov rcx, qword [endOfArena]
    sub rcx, rsi
    inc ecx             ;Add EOF char to the count
    rep movsb
    dec rdi             ;Go back to the EOF char
    mov qword [eofPtr], rdi
    movzx ebx, word [xfrHdl]
    mov eax, 3E00h      ;Close handle!
    int 21h
    return


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File block moving functions (copying and cutting and pasting)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;Both following functions need 3 arguments, but empty args are permitted!
moveLines:
;Moves a block of lines elsewhere (non overlapping moves only)
;--------------------------------------------
;Invoked by: [line],[line],lineM
;--------------------------------------------
    cmp byte [argCnt], 3
    jne printComErr
    mov byte [movCpFlg], -1
    jmp copyLines.common
copyLines:
;Duplicates a line or a range of lines to a position specifed 
;   (non-overlapping) 
;--------------------------------------------
;Invoked by: [line],[line],line[,count]C
;--------------------------------------------
    cmp byte [argCnt], 3    ;This can be 3 or 4 arguments!
    jb printComErr
    mov byte [movCpFlg], 0
.common:
;arg1 = Start line of range for copy, default to current line
;arg2 = End line of range for copy, default to line after current line
;arg3 = Line to place it at, no default, cant be 0!
;arg4 = Number of times to consecutively repeat the copy (copy only)
    movzx ebx, word [arg3]  ;Check the mandatory argument
    test ebx, ebx   ;Are we 0?
    lea rdx, badDestStr
    jz printErr
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .gotStart
    movzx ebx, word [curLineNum]
    call checkArgOrder  ;Check that this is before arg2
    mov word [arg1], bx
.gotStart:
    call findLine   ;Get in rdi the ptr to the first argument
    jnz printComErr ;If the line is not found, we gotta complain!
    mov qword [blkPtrSrc], rdi  ;Save the ptr to the line!
    movzx ebx, word [arg2]
    test ebx, ebx
    jnz .gotEnd
    ;Set the default line!
    movzx ebx, word [curLineNum] 
    mov word [arg2], bx
.gotEnd:
    push rbx            ;Save this line number
    call findLine       ;Ensure the line in bx exists
    pop rbx
    jnz printComErr     ;Again, if the line not found, complain!
    inc ebx             ;Now increment the line number to get line after
    call findLine   ;This can be end of arena since this is end of copy blk
    mov qword [blkPtrEnd], rdi     
;We mightve changed the second argument so double check it!
    movzx ebx, word [arg1]
    cmp bx, word [arg2]
    ja printComErr
;Now we check against the third line. It must not be in the range 
; specified, else error (cannot overlap copies or moves!!!)
    movzx ebx, word [arg3]    ;Get the storage line
    cmp bx, word [arg1]     ;arg3 <= arg1?
    jbe .argsOk
    cmp bx, word [arg2]     ;arg3 > arg2 ?
    jbe printComErr
.argsOk:
    mov rcx, qword [blkPtrEnd]
    sub rcx, qword [blkPtrSrc]  ;Get the size of one block that we will move
    mov dword [blkSize], ecx
    movzx eax, word [arg4]      ;Get the count length
    test eax, eax
    jz .noCount     ;If nothing, ecx is the copy size too
;Here we compute the copySize as a multiple of blkSize
    mul ecx
    test edx, edx   ;Is this larger than a dword (should never happen!)
    jnz printMemErr ;Bad arg4!!
    mov ecx, eax    ;Make ecx the size of the copy
.noCount:
    mov dword [copySize], ecx
;Now, can we fit our new section of text in memory?
    mov rbx, qword [eofPtr]
    mov rdx, qword [endOfArena]
    sub rdx, rbx
    cmp edx, ecx
    jb printMemErr  ;Insufficient memory error!!
;Finally, get the line we will place copy at!
    movzx ebx, word [arg3]
    call findLine
    mov qword [cpyPtrDest], rdi ;Now save ptr to the line we copy to!
;Now make space for one load of the copy
    mov rsi, qword [eofPtr]
    mov rcx, rsi
    sub rcx, rdi    ;Get the number of bytes we will shift
    inc ecx         ;Add EOF
    mov rdi, rsi    ;This is the destination
    mov eax, dword [copySize]
    add rdi, rax    ;Go to the destination
    mov qword [eofPtr], rdi ;This is the new eof position!
    std
    rep movsb   ;Now copy in reverse to be safe :)
    cld
;Adjust blkPtrs if they were in this region.
    mov rbx, qword [cpyPtrDest]
    cmp rbx, qword [blkPtrSrc]
    ja .ptrsOk
    mov ecx, dword [copySize]    ;Add this amount to the ptrs
    add qword [blkPtrSrc], rcx
    add qword [blkPtrEnd], rcx
.ptrsOk:
    movzx ebx, word [arg4]  ;Get count word to use as counter
    mov rdi, qword [cpyPtrDest] ;Write to here!
.cpLp:
    mov ecx, dword [blkSize]
    mov rsi, qword [blkPtrSrc]  ;Start the copy from here
    rep movsb
    sub ebx, 1  ;Default is 0, if we are below 0, set CF with sub
    jnc .cpLp   ;If CF not yet set, keep going!
    cmp byte [movCpFlg], 0  ;Was this a move or a copy?
    je .copyDone
;Now pull everything back over the source of the move
    mov rdi, qword [blkPtrSrc]
    mov rsi, qword [blkPtrEnd]
    mov rcx, qword [eofPtr]
    sub rcx, rsi    ;Get the number of bytes to move 
    inc rcx         ;Include EOF
    rep movsb
    dec rdi         ;Go back to the EOF char itself
    mov qword [eofPtr], rdi
    movzx ebx, word [arg3]
    cmp bx, word [arg1] ;Was this in the range of the move?
    jbe .copyDone
    ;If it was, add the difference - 1
    add bx, word [arg1]
    sub bx, word [arg2]
    dec bx 
    mov word [arg3], bx
.copyDone:
    movzx ebx, word [arg3]
    call findLine
    mov qword [curLinePtr], rdi
    mov word [curLineNum], bx
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File searching functions
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

searchText:
;Searches text for a string
;--------------------------------------------
;Invoked by: [line][,line][?]S[string]
;--------------------------------------------
    jmp _unimplementedFunction

replaceText:
;Replaces all matching strings with specified string (NO REGEX)
;--------------------------------------------
;Invoked by: [line][,line][?]R[string]<EOF>[string]
;--------------------------------------------
    jmp _unimplementedFunction


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File listing functions
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

listLines:
;Prints a line or a number of lines.
;Defaults to from current line print 23 lines.
;Doesnt change the current line!
;--------------------------------------------
;Invoked by: [line][,line]L
;--------------------------------------------
    cmp byte [argCnt], 2
    ja printComErr
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .notCur ;If not the default, we do as told
    ;Else, default behaviour
    movzx ebx, word [curLineNum]
    sub ebx, 11 ;Start printing 11 lines before the current line!
    ja .notCur  
    mov ebx, 1
.notCur:
    call findLine
    retnz   ;Return if the line not found!
    mov rsi, rdi
    movzx edi, word [arg2]  ;Get the last line to print
    inc edi
    sub edi, ebx            ;Get the difference!
    ja printLines   
    mov edi, 23     ;Else the default
    jmp printLines  ;Return through printLines!

pageLines:
;Prints a page of lines
;Defaults to from current line to print 23 lines
;Changes the current line to the last line printed!
;--------------------------------------------
;Invoked by: [line][,line]P
;--------------------------------------------
    cmp byte [argCnt], 2
    ja printComErr
    xor ebx, ebx    ;Set the pointer to the end of the file firstly
    call findLine   
    ;Use r10 to keep track of the last line in the file that we will set
    mov r10, rdx
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .notCur
    movzx ebx, word [curLineNum]
    cmp ebx, 1  ;If the first line is 1, keep it there
    je .notCur
    inc ebx     ;Else go to the line after
.notCur:
    cmp rbx, r10
    reta    ;If we specify past the last line, do nothing
    movzx edx, word [arg2]  
    test edx, edx   ;Did the user give what line to stop printing on?
    jnz .arg2Given 
;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
;Here is where the screen width is computed when we do dynamic 
; screen size stuff
    mov edx, ebx
    add edx, 22     ;Else its current line + 23
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
.arg2Given:
    inc edx         ;Get that last line
    cmp rdx, r10    ;Is it past the end of the file?
    jbe .okRange
    mov rdx, r10    ;Else, use r10 as the last line
.okRange:
    push rdx        ;Save the end line
    push rbx        ;and the start line
    mov ebx, edx    ;Now setup the pointers to point to the last line
    dec ebx         
    call findLine   ;Get the actual line number in dx and ptr in rdi
    mov word [curLineNum], dx
    mov qword [curLinePtr], rdi
    pop rbx         ;Get back the actual start line
    call findLine   ;Now find the first line!
    mov rsi, rdi    ;This is the source of the copy
    pop rdi         ;Get the end line count in edi
    sub edi, ebx    ;Get the number of lines to print in edi
    jmp printLines  ;Return through printLines!

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File IO control functions
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

appendLines:
;If the file is not fully loaded in arena, allows you to load 
; the next portion into the arena. Essentially ignores the 
; input and always fills up to the 3/4 limit.
;--------------------------------------------
;Invoked by: [n]A (number of bytes to read)
;--------------------------------------------
    cmp byte [argCnt], 1
    jne printComErr
    test byte [eofReached], -1
    jnz .outEofStr   ;Print the eof reached string
    mov rdx, qword [eofPtr]
    cmp byte [arg1], 0          ;Arg <> 0 means we fill the arena
    jne .argGiven
    cmp rdx, qword [fillPtr]    ;Are we at/past the fill point?
    retnb   ;Return if so!
.argGiven:
;rdx -> The start of the read in buffer
    mov rcx, qword [endOfArena] ;Fill the arena
    sub rcx, rdx        ;Get the number of bytes to read
    jz printMemErr      ;If we @ end of arena, free some space!!
    mov r10, rcx        ;Use r10 to save byte count we want to read in
    movzx ebx, word [readHdl]
    mov eax, 3F00h
    int 21h
    cmp eax, ecx
    je .notEof
    ;Check this is really the eof (by trying to read one more byte)
    push rax    ;Save the byte count
    add rdx, rax
    mov ecx, 1
    mov eax, 3F00h
    int 21h
    mov ecx, eax
    pop rax     ;Get original byte count back
    jc badReadFail
    test ecx, ecx   ;Did we read bytes?
    jnz .notEofInc  ;If not, inc byte count!
    mov byte [eofReached], -1   ;Else, set the flag!!
.notEofInc:
    inc eax
.notEof:
    add rdx, rax        ;rax has the number of bytes we have read
    mov ecx, eax        ;Save the byte count in ecx
    mov rdi, qword [eofPtr] ;Point rdi to the start of the read in region
    mov r11, rcx            ;Save real byte count in r11 temporarily
    call checkEOF
    jnz .noSetEof   ;Set the byte here if ZF=ZE on return
    mov byte [eofReached], -1   ;to keep it all on the same level!
.noSetEof:
    movzx ebx, word [arg1]  ;Get the line number to read in to
    test ebx, ebx
    jnz .fndLine    ;If we are searching for line 0, go to the end
    mov rax, rdi
    add rax, rcx    ;Move the the end of the text we read in
    cmp rax, qword [fillPtr]
    jbe .fndLine    ;If we are leq than fill point, scan for the lnnum  in bx!
    ;Else we search for one line past the fillPtr at most
    mov rcx, rax
    mov rdi, qword [fillPtr]
    sub rcx, rdi    ;Get the excess of bytes to scan for the line
    mov ebx, 1      ;Make sure we count only 1 line!
.fndLine:
    xor edx, edx    ;Set the line counter to start at 0
    call findLineCore   ;Returns al = LF, rdi -> either LF or first char after ecx
    cmp byte [rdi - 1], al
    je .lineOk
;Here we ran out of chars to scan through
    test byte [eofReached], -1
    jnz .findPrevLine   ;If not at EOF, and ran out of chars, go to prev line
    ;Else, at EOF and ran out of chars, add a CRLF
    mov eax, CRLF   ;Store in the empty space pointed to by rdi
    stosw    
    add r11, 2  ;Added two more chars to the count
    jmp short .lineOk
.findPrevLine:
    dec edx     ;Remember we have to dec the line number
    dec rdi     ;Point to the char previous to start searching at
    mov ecx, dword [arenaSize]  ;Get the size of the allocation to search thru
    std
    repne scasb ;Scan for the LF in al
    cld
    add rdi, 2  ;Go to first char past it
.lineOk:
    mov byte [rdi], EOF ;Add the terminating EOF char here!
    mov rcx, r11    ;Get back the real byte count
    add rcx, qword [memPtr] ;Get ptr to last byte we actually read in
    sub rcx, rdi    ;Get the excess number of chars we added since reading in
    xchg qword [eofPtr], rdi    ;Swap the old and new EOF char ptrs
    add rdi, rcx    ;Adjust file ptr by amount we read in but ignored
    test rdi, rdi
    jz .noIgnore    ;We ignored no bytes read in, proceed
    ;Else, we are at the previous line, so move file ptr there!
    push rbx
    push rdx
    mov rdx, rdi
    mov rcx, -1
    mov eax, 4201h  ;Seek from current position by the amount in dx
    int 21h
    pop rdx
    pop rbx
    jc badReadFail
.noIgnore:
    cmp ebx, edx    ;Is the line number specified = line number we are at?
    jne .checkEnd
    mov byte [eofReached], 0    ;Reset byte if this is the case (adding new lines)
    return
.outEofStr:
    lea rdx, eofStr
    call printString
    return
.checkEnd:
    test byte [eofReached], -1
    jnz .outEofStr
    test byte [noAppendErr], -1 ;Ignore EOF errors on initial load!
    retnz 
    jmp printMemErr

writeLines:
;Writes the current arena to disk. If no 
; n specified, EDLIN writes lines until
; 1/4 of the arena is free.
;--------------------------------------------
;Invoked by: [n]W (number of bytes to write)
;--------------------------------------------
;When invoked, must delete the backup if it not already deleted.
    cmp byte [argCnt], 1
    ja printComErr
    movzx ebx, word [arg1]
    test ebx, ebx
    jnz .goFindLine
    ;If 0, means, write everything from 1/4 onwards
    mov ecx, dword [freeCnt]    ;Get the count of 1/4 of the arena
    mov rdi, qword [eofPtr]
    sub rdi, rcx    ;Move rdi back by a quarter
    retbe           ;If the result is leq 0, fail (never will happen)
    cmp rdi, qword [memPtr] ;Are we pointing before the start of the arena
    retbe           ;Return as we have nothing to write!
    ;rdi now points back by a quarter
    xor edx, edx    ;Init to "line 0"
    mov ebx, 1      ;Find the end of the line we are
    call findLineCore
    jmp short .prepWrite
.goFindLine:
    inc ebx     ;Find line 1 (user said 0, this means 1 for us!)
    call findLine
.prepWrite:
    call delBkup    ;Delete the backup, all regs preserved
    mov rcx, rdi    ;rdi points to up to where to do the write
    mov rdx, qword [memPtr] ;Start writing from here
    sub rcx, rdx    ;Get the byte offset into the arena
    movzx ebx, word [writeHdl]
    mov eax, 4000h
    int 21h
    jc fullDiskFail
    cmp eax, ecx
    jne fullDiskFail
    ;Now pull up the rest of the arena and reset the internal line numbers
    mov rsi, rdi    ;Source chars from here
    mov rdi, qword [memPtr]
    mov qword [curLinePtr], rdi
    mov word [curLineNum], 1    ;Go back to line 1 again
    mov rcx, qword [eofPtr]
    sub rcx, rsi    ;Get the number of bytes left in the arena to pull up
    inc ecx         ;Copy the EOF marker too
    cld 
    rep movsb
    dec rdi         ;Go back to EOF
    mov qword [eofPtr], rdi
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Exit functions
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

endEdit:
;Inserts a EOF char at the end of the file if one not already present
; renames the original file (if applicable) to have .bak ending and
; renames the working file to the name originally specified.
;--------------------------------------------
;Invoked by: E
;--------------------------------------------
    cmp byte [argCnt], 1
    jne printComErr
    cmp byte [arg1], 0
    jne printComErr
    test byte [roFlag], -1  ;If we are readonly, delete $$$ and quit
    jnz quit.roQuit
    mov byte [noAppendErr], -1  ;Suppress errors again
.writeLp:
    mov ebx, -1             ;Write out max lines
    call writeLines.goFindLine
    test byte [eofReached], -1  ;Are we at EOF yet?
    jnz .writeDone  ;If yes, we are done writing to disk
    mov byte [argCnt], 1    ;Else we keep reading the file
    mov word [arg1], -1     ;Now fill the arena with lines
    call appendLines
    jmp short .writeLp      ;And write them out again
.writeDone:
    mov rdx, qword [eofPtr] ;Now write out the EOF char to the file
    mov ecx, 1
    movzx ebx, word [writeHdl]
    mov eax, 4000h
    int 21h
    movzx ebx, word [readHdl]
    mov eax, 3E00h  ;Close the reading file!
    int 21h
    movzx ebx, word [writeHdl]  ;Get the write handle
    mov eax, 3E00h  ;Close the temp file!
    int 21h
    test byte [newFileFlag], -1  ;If this is new file, skip this!
    jnz short .skipBkup
    ;Now set the backup extension
    mov rdi, qword [fileExtPtr]
    mov eax, "BAK"
    stosd
    lea rdx, pathspec
    lea rdi, bkupfile
    mov eax, 5600h
    int 21h
.skipBkup:
    mov eax, "$$$"  ;Always set this as triple dollar as this is saved name!
    mov rdi, qword [fileExtPtr]
    stosd
    lea rdx, bkupfile
    lea rdi, pathspec   ;Now name the temp file by the og name!
    mov eax, 5600h
    int 21h
    retToDOS errOk ;Let DOS do cleanup of memory allocations!

quit:
;Quits EDLIN, not saving work and deleting working file.
;--------------------------------------------
;Invoked by: Q
;--------------------------------------------
    cmp byte [roFlag], -1   ;If the flag is clear, dont prompt, just quit.
    je short .roQuit
    lea rdx, exitQuit
    mov eax, 0900h
    int 21h
    mov eax, 0C01h  ;Flush input buffer and read a single char from stdin
    int 21h
    movzx ebx, al
    and ebx, 0DFh    ;Convert to upper case
    cmp ebx, "Y"
    jne printCRLF   ;Print CRLF and return via that return instruction
    ;Delete the working file
.roQuit:
    mov rdi, qword [fileExtPtr]
    mov eax, "$$$"
    stosd
    lea rdx, wkfile
    mov eax, 4100h  ;Delete the file
    int 21h
    retToDOS errOk