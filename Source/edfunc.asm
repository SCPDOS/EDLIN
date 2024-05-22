;This is where the main user selectable routines are
;All arguments specified are signed words

;Arguments above these limits will throw an error and the input
; will be discarded.

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
    retnz   ;Return if we are already at the end of the file!
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
    retc
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

copyLines:
;Duplicates a line or a range of lines to a position specifed 
;   (non-overlapping) 
;--------------------------------------------
;Invoked by: [line],[line],line[,count]C
;--------------------------------------------
    jmp _unimplementedFunction

deleteLines:
;Deletes one or a range of lines
;--------------------------------------------
;Invoked by: [line][,line]D
;--------------------------------------------
    jmp _unimplementedFunction

editLine:
;Displays a line and allows it to be edited
;--------------------------------------------
;Invoked by: [line]
;--------------------------------------------
    dec qword [charPtr] ;Adjust ptr to point to the CR or ;
    lea rdx, getCommand
    mov eax, 2523h  ;Set the int 23h handler
    int 21h

    jmp _unimplementedFunction

endEdit:
;Inserts a EOF char at the end of the file if one not already present
; renames the original file (if applicable) to have .bak ending and
; renames the working file to the name originally specified.
;--------------------------------------------
;Invoked by: E
;--------------------------------------------
;1) Append a final EOF to the file if doesnt have one and del bkup 
;       if not yet done so.
;2) Write file to temp file.
;   |__>If this fails, return to command line (to allow abort).
;3) Close the original file.
;4) Close the temp file.
;5) Rename OG file to .BAK.
;   |__>If this fails, delete the original .BAK and try again.
;       If it fails again, exit with .$$$ file. Print no disk space error.
;6) Rename temp file to OG filename. 
;   |__>If it fails, exit with .$$$ file. Print no disk space error.
;7) Exit!
;--------------------------------------------
    ;Stage 1
    cmp byte [argCnt], 1
    jne printComErr
    cmp byte [arg1], 0
    jne printArgError
    test byte [roFlag], -1  ;If we are readonly, delete $$$ and quit
    jnz quit.roQuit
    mov byte [noAppendErr], -1  ;Suppress errors again
.writeLp:
    mov ebx, -1             ;Write out max lines
    call writeLines.goFindLine
    test byte [eofReached], -1  ;Are we at EOF yet?
    jnz .writeDone
    ;Else we need to append again
    mov byte [argCnt], 1
    mov word [arg1], -1    ;Now read max lines
    call appendLines
    jmp short .writeLp
.writeDone: ;If so, add the EOF char to the file!
    mov rdx, qword [eofPtr]
    mov ecx, 1
    movzx ebx, word [writeHdl]
    mov eax, 4000h
    int 21h
    ;Stage 3
    movzx ebx, word [readHdl]
    mov eax, 3E00h  ;Close the reading file!
    int 21h
    ;Stage 4
    movzx ebx, word [writeHdl]  ;Get the write handle
    mov eax, 3E00h  ;Close the temp file!
    int 21h
    ;Stage 5
    test byte [newFileFlag], -1  ;If this is new file, skip this!
    jnz short .skipBkup
    ;Now set the backup extension
    mov rdi, qword [fileExtPtr]
    mov eax, "BAK"
    stosd
.stg4:
    lea rdx, pathspec
    lea rdi, bkupfile
    mov eax, 5600h
    int 21h
    ;Stage 5
.skipBkup:
    mov eax, "$$$"  ;Always set this as triple dollar as this is saved name!
    mov rdi, qword [fileExtPtr]
    stosd
    lea rdx, bkupfile
    lea rdi, pathspec   ;Now name the temp file by the og name!
    mov eax, 5600h
    int 21h
    retToDOS errOk ;Let DOS do cleanup of memory allocations!

insertLine:
;Inserts a line
;--------------------------------------------
;Invoked by: [line]I
;--------------------------------------------
;If a user types CTRL+V, then the next
; UPPERCASE char is taken to be a control
; char. Else, we throw away the ^V from the 
; line before saving it.
    jmp _unimplementedFunction

listLines:
;Prints a line or a number of lines.
;Defaults to from current line print 23 lines
;--------------------------------------------
;Invoked by: [line][,line]L
;--------------------------------------------
    jmp _unimplementedFunction

pageLines:
;Prints a page of lines
;Defaults to from current line to print 23 lines
;--------------------------------------------
;Invoked by: [line][,line]P
;--------------------------------------------
    jmp _unimplementedFunction

moveLines:
;Moves a block of lines elsewhere (non overlapping moves only)
;--------------------------------------------
;Invoked by: [line][line],lineM
;--------------------------------------------
    jmp _unimplementedFunction

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

replaceText:
;Replaces all matching strings with specified string (NO REGEX)
;--------------------------------------------
;Invoked by: [line][,line][?]R[string]<EOF>[string]
;--------------------------------------------
    jmp _unimplementedFunction

searchText:
;Searches text for a string
;--------------------------------------------
;Invoked by: [line][,line][?]S[string]
;--------------------------------------------
    jmp _unimplementedFunction

transferLines:
;Writes the lines specified to the specified file
;--------------------------------------------
;Invoked by: [line]T[d:]filename
;--------------------------------------------
    jmp _unimplementedFunction

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