;Main EDLIN file
start:
    jmp short .cVersion
.vNum:          db 1    ;Main version number, patchable
.cVersion:
    movzx ebx, al   ;Save drive number validity in bl
    cld
    mov eax, 3000h  ;Get version number
    int 41h
    cmp al, byte [.vNum]
    jbe short okVersion
    lea rdx, badVerStr
badExitMsg:
    test rdx, rdx   ;Check if null ptr => Dont print on exit
    jz short .noPrint
    mov eax, 0900h
    int 41h
.noPrint:
    mov eax, 4CFFh
    int 41h
okVersion:
;Initialise the BSS and to 0
    lea rdi, section..bss.start
    mov rcx, bssLen
    xor eax, eax
    rep stosb
;One command line argument except for mandatory filename, /B=(binary read)
    mov eax, 3700h
    int 41h
    mov bh, dl  ;Preserve switch char in bh

    mov eax, 6101h  ;Get parsed FCB and cmdtail for filename in rdx
    int 41h
;Now parse the command line, to get full command spec for filename.
    lea rdi, qword [rdx + cmdArgs.progTail] ;Get ptr to tail
    movzx ecx, byte [rdx + cmdArgs.parmList]    ;Get number of chars in cmdline
    lea rdx, badNameStr ;Prep for error message
    mov al, SPC ;Now we search for a space. No leading spaces on cmdine
    repne scasb
    test ecx, ecx   ;If no chars left (even on equality with SPC) fail
    jz short badExitMsg
    repe scasb  ;Now skip the spaces
    test ecx, ecx   ;If we run out of chars, fail as no filename
    jz short badExitMsg
    dec rdi ;Point rdi to the start of the filename as given
    mov qword [tmpNamePtr], rdi    ;Save the ptr to the filename
    inc rdi ;Go back where it was
    mov rsi, rdi
.findEndLoop:
    lodsb
    cmp al, SPC
    je short .endFoundSpc
    cmp al, CR
    je short .endFound
    dec ecx
    jz short badExitMsg
    jmp short .findEndLoop  ;Keep looking for the end of the string
.endFoundSpc:
;If a space found now search for a switch, continue decrementing ecx
    mov rdi, rsi    ;Points at first char past CR/SPC terminator
    mov al, bh  ;Get the switch char back
    repne scasb   ;Search for switchChar, modify rdi
    jne short .endFound ;If we come out here and no switchchar found, exit check
    cmp byte [rdi], "B" ;Was the char after the switchChar a B (binary mode)?
    lea rdx, badParm
    jne badExitMsg  ;If not, exit
    mov byte [noEofCheck], -1   ;Else, set the flag
.endFound:
    dec rsi ;Move rsi back to the terminating char
    xor eax, eax
    mov byte [rsi], al  ;Store terminating NULL
;Now check if the drive is specified that it is valid
    mov rsi, qword [tmpNamePtr]
    mov ax, word [rsi]  ;Get the first two chars of file name
    cmp ah, ":"
    jne short .noDriveSpecified
    ;Check if drive specified is OK, bl has signature
    lea rdx, badDrvStr
    cmp bl, -1
    je badExitMsg
.noDriveSpecified:
;Now we canonicalise the filename since now it is ASCIIZ
    lea rdi, pathspec
    mov eax, 6000h  ;Truename the path in rsi to rdi
    int 41h
    ;Now get a pointer to the file name and file extension
    mov ecx, 68
    xor eax, eax    ;Find the null terminator
    repne scasb
    jecxz .badPathError
    mov al, "\"     ;Find the first pathsep backwards
    mov ecx, 14
    std
    repne scasb
    cld
    jecxz .badPathError
    add rdi, 2 ;Point to the first char in the filename
    mov qword [fileNamePtr], rdi
    mov rsi, rdi
    ; Now find the extension (or add one if no extension)
.extSearch:
;Keep searching for . or NUL in filename portion of path
    lodsb
    cmp al, "."
    je short .extFnd
    test al, al
    jnz short .extSearch
;No extension found, add one made of spaces
    dec rsi ;Point rdi back at the null char
    mov qword [fileExtPtr], rsi
    mov rdi, rsi
    mov eax, ".   "    ;dot and three spaces (obviously)
    stosd
    xor eax, eax
    stosb
    jmp short .pathComplete
.extFnd:
;rsi points to the first char of the extension (not the dot)
    dec rsi
    mov qword [fileExtPtr], rsi
    inc rsi ;Go back to the first char past the dot
    mov rdi, rsi
    mov ecx, 3  ;Three chars in the extension
    xor eax, eax
    repne scasb   ;Look for the terminating null
    jecxz .pathComplete ;Already a three char extension
    dec rdi ;Go back to terminating null and overwrite it
    mov al, " "
    rep stosb   ;Store the number of remaining spaces
    xor eax, eax
    stosb
    jmp short .pathComplete
.badPathError:
    lea rdx, badFileStr
    jmp badExitMsg
.pathComplete:
;Paths can only be a max of 67 chars but the DTA buffer is 127 bytes
; so if no extension is provided or too short an extension is provided,
; simply add space for the extension.

;Now realloc memory. No need to add the extra paragraph, but we 
; do so for as to protect the top of stack from enemy programs 
; with "segfault-ish" behaviour
    lea rsp, stackTop
    lea rbx, endOfProgram   ;Guaranteed paragraph alignment
    sub rbx, r8 ;Get number of bytes in block
    shr rbx, 4  ;Convert to paragraphs
    inc rbx     ;Add one more paragraph for good measure
    mov eax, 4A00h
    int 41h
    lea rdx, badRealloc
    jc badExitMsg
;
;Now we want to allocate our scratchpad space for the file!
;


;Now we proceed with opening the file/creating if it is new.
fileSearch:
    mov rdx, rdi    ;Get the file name pointer
    mov ecx, 27h    ;Inclusive search (Archive, System, Hidden, Read-Only)
    mov eax, 4E00h  ;Find the file!
    int 41h
    jnc short .fileExists
    cmp al, errFnf
    je short .createFile
    lea rdx, badOpenStr
    jmp badExitMsg
.createFile:
;If we are creating the file, its a new file.
;Set variables appropriately.
    mov eax, 3C00h  ;Create file
    xor ecx, ecx    ;Regular attributes
    int 41h
    lea rdx, badCreatStr
    jc badExitMsg
    mov word [fileHdl], ax
    lea rdx, newStr
    mov eax, 0900h  ;Write the "new file" string
    int 41h
    jmp mainLoop
.fileExists:
;If we are here, we are opening the file.
    mov eax, 2F00h
    int 41h     ;Get DTA pointer in rbx
    mov cl, byte [rbx + ffBlock.attribFnd]
    lea rdx, badDirStr
    test cl, fileDir    ;Is dir bit set?
    jnz badExitMsg
    xor eax, eax
    xor ebx, ebx
    dec ebx
    test cl, fileRO      ;Is the RO bit set?
    cmovnz eax, ebx ;Move -1 into al if RO bit set
    mov byte [roFlag], al   ;Set the ro flag appropriately


mainLoop:


exitOk:
;Let DOS take care of freeing all resources
    mov eax, 4C00h
    int 41h


