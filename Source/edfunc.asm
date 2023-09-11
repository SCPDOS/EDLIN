;This is where the main user selectable routines are
;All arguments specified are signed words

;Arguments above these limits will throw an error and the input
; will be discarded.

appendLines:
;If the file is not fully loaded in arena, allows you to load 
; the next portion into the arena. Reads byte by byte from 
; the file until the desired number of CRLF's have
; been hit (inefficient?) or (appropriate) EOF condition.
;If no n specified, we write the first 1/4 of the arena 
; and shift the rest of the lines up.
;--------------------------------------------
;Invoked by: [n]A (number of bytes to read)
;--------------------------------------------
    jmp _unimplementedFunction

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
    movzx eax, word [arg1]  ;Get the line number into eax
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
    test byte [roFlag], -1  ;If we are readonly, delete $$$ and quit
    jnz quit.roQuit
    call appendEOF  ;Append an EOF if appropriate.
    call delBkup
    test byte [dirtyFlag], -1   ;If we are clean, delete $$$ and quit
    jz quit.roQuit
.newFile:
    ;Stage 2
    mov ecx, dword [textLen]    ;Get number of chars in the arena to write
    mov rdx, qword [memPtr]     ;Get the ptr to the start of the text
    movzx ebx, word [writeHdl]  ;Get the write handle
    mov eax, 4000h
    int 41h
    jc .writeError
    ;Stage 3
    movzx ebx, word [readHdl]
    mov eax, 3E00h  ;Close the reading file!
    int 41h
    ;Stage 4
    movzx ebx, word [writeHdl]  ;Get the write handle
    mov eax, 3E00h  ;Close the temp file!
    int 41h
    ;Stage 5
    ;Use ecx as a flag, if rename fails with flag set, then
    ; quit with temp name! Skip if this is a new file!
    test byte [newFileFlag], -1  ;If this is new file, skip this!
    jnz short .skipBkup
    ;Now set the backup extension
    mov rdi, qword [fileExtPtr]
    mov eax, "BAK"
    stosd
    xor ecx, ecx
.stg4:
    lea rdx, pathspec
    lea rdi, bkupfile
    mov eax, 5600h
    int 41h
    jc short .badBkup
    ;Stage 5
.skipBkup:
    mov eax, "$$$"  ;Always set this as triple dollar as this is saved name!
    mov rdi, qword [fileExtPtr]
    stosd
    lea rdx, bkupfile
    lea rdi, pathspec   ;Now name the temp file by the og name!
    mov eax, 5600h
    int 41h
    jc short .badBkup2
.exit:
    retToDOS errOk ;Let DOS do cleanup of memory allocations!
.writeError:
    call .dskFull
    retToDOS errDskFull
.dskFull:
    lea rdx, badDskFull ;Write disk full error, but return to prompt
    mov eax, 0900h
    int 41h
    return
.badBkup:
    test ecx, ecx   ;If this is not our first time here, bkup exit!
    jnz short .badBkup2
    dec ecx
    mov rdx, rdi    ;Try and delete the backup
    mov eax, 4100h
    int 41h
    jmp short .stg4
.badBkup2:
;Since handles are now closed, we must exit with default filenames
    call .writeError    ;Write disk full error, but then exit!
    retToDOS errBadRen  ;Return to DOS, bad rename error

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
    int 41h
    mov eax, 0C01h  ;Flush input buffer and read a single char from stdin
    int 41h
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
    int 41h
    retToDOS errOk

replaceText:
;Replaces all matching strings with specified string (NO REGEX)
;--------------------------------------------
;Invoked by: [line][,line][?]R[string][<F6>string]
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
    jmp _unimplementedFunction