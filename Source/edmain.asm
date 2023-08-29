;Contains the program loader
start:
    jmp short .cVersion
.vNum:          db 1    ;Main version number, patchable
.cVersion:
    cld
    mov eax, 3000h  ;Get version number
    int 41h
    cmp al, byte [.vNum]
    jbe short okVersion
    lea rdx, badVerStr
    jmp badExitMsg
okVersion:
;Initialise the BSS and to 0
    lea rdi, section..bss.start
    mov rcx, bssLen
    xor eax, eax
    rep stosb
;One command line argument except for mandatory filename, /B=(binary read)
    mov eax, 3700h
    int 41h
    mov eax, "\"    ;Default pathsep
    mov ecx, "/"    ;Alternative pathsep
    cmp dl, "-"     ;Is the switch char default or alternative?
    cmove eax, ecx  ;Move if alternative
    mov bl, dl  ;Preserve switch char in bl
    mov byte [switchChar], bl
    mov byte [pathsepChar], al
getCmdTail:
    mov eax, 6101h  ;Get parsed FCB and cmdtail for filename in rdx
    int 41h
;Now parse the command line, to get full command spec for filename.
    lea rdi, qword [rdx + cmdArgs.progTail]     ;Get ptr to tail
    movzx ecx, byte [rdx + cmdArgs.parmList]    ;Get number of chars in cmdline
cmdTailParse:
    mov al, SPC ;Comparing against a space
.searchLoop:
    repe scasb  ;Search for the first non-space char
    jecxz .parseComplete    ;If we run out of chars, exit!
    cmp byte [rdi - 1], bl  ;Did we find a switchchar?
    jne short .notSwitch
    mov al, byte [rdi]      ;Get the char after the switch
    ;Now we lookahead only if we have more than 1 char left in buffer
    cmp ecx, 1  ;If we have 1 char left, automatically accept as arg
    je short .goodSwitch
    mov ah, byte byte [rdi + 1] ;Lookahead
    cmp ah, SPC ;If char after switchchar is SPC, accept
    je short .goodSwitch
.parseBadExit:
    jmp badParmExit
.nameBadExit:
    lea rdx, badNameStr
    jmp badExitMsg
.goodSwitch:
    and al, ~20h    ;Clear the lowercase flag
    cmp al, "B"     ;The flag is /B
    jne short .parseBadExit
    mov byte [noEofCheck], -1   ;Set the internal flag
    inc rdi ;Move rdi to the char after the B
    dec ecx ;And decrement count of chars left
    jz short .parseComplete
    jmp short .searchLoop   ;Now skip next lot of spaces
.notSwitch:
    ;Thus rdi must point one char past the start of a filename. 
    ;If there is no filename, accept the pointer. 
    ;If not, fail.
    cmp qword [tmpNamePtr], 0
    jnz short .parseBadExit ;If its not empty, too many filenames passed in
    dec rdi
    mov qword [tmpNamePtr], rdi ;Store the ptr temporarily here
    inc rdi
    repne scasb ;Now we keep going until we hit a space
    mov qword [tmpNamePtr2], rdi    ;Store first char past end of name here.
    cmp byte [rdi - 1], al  ;Was this a space or run out of chars?
    je short .searchLoop    ;Jump if a space, else, we parsed the tail.
.parseComplete:
;Check we have a pointer to a filename AT LEAST.
    cmp qword [tmpNamePtr], 0
    je short .nameBadExit
;Now we copy the filename internally.
    lea rdi, pathspec
    mov rsi, qword [tmpNamePtr]
nameCopy:
    movsb   ;Copy one char at a time
    cmp rsi, qword [tmpNamePtr2]    ;Check if we are equal to end of string ptr
    jne short nameCopy
    xor eax, eax
    stosb   ;Store the null terminating char
    lea rdi, pathspec
    mov rsi, rdi
    mov eax, 6000h  ;TRUENAME the filename
    int 41h
    jnc short .nameGood ;Name ok, proceed
    cmp al, errBadDrv
    jne short .genericError
    lea rdx, badDrvStr
    jmp badExitMsg
.genericError:
    lea rdx, badFileStr ;If this fails, bad filespec
    jc badExitMsg  ;The filename is bad for some reason!
.nameGood:
    ;Now invalidate tmpNamePtr and tmpNamePtr2
    xor ecx, ecx
    mov qword [tmpNamePtr], rcx
    mov qword [tmpNamePtr2], rcx
    dec rcx
    lea rdi, pathspec
    xor eax, eax
    rep scasb   ;rdi points past terminating null
    ;Find the nearest pathsep (since we have fully qualified the name)
    std
    movzx eax, byte [pathsepChar]   ;Get pathsep char in al
    rep scasb
    cld
    add rdi, 2  ;Point rdi to first char past the pathsep
    mov qword [fileNamePtr], rdi    ;Save the ptr
    ;Now convert into an FCB name and back to ASCIIZ string 
    ; at the end of the provided pathspec
    mov rdi, rsi
    lea rdi, fcbBuffer
    push rsi
    push rdi
    call asciiToFCB
    pop rsi ;Swap the pointers
    pop rdi
    call FCBToAsciiz
    mov al, "."
    mov rdi, qword [fileNamePtr]    ;Get the ptr to the 8.3 filename
    mov ecx, 8
    repne scasb   ;Now scan for the extension separator
    ;rdi points just after the separator.
    mov qword [fileExtPtr], rdi
;Now we have all the metadata for the filename we are working with
    lea rdx, badFileExt
    mov eax, dword [rdi]
    cmp eax, "BAK"  ;Is this a bakup file?
    je badExitMsg   ;If yes, error!
;Now we check to make sure the path has no global filename chars
wildcardCheck:
    lea rsi, pathspec
.mainlp:
    lodsb
    test al, al ;Once we're at the null char, proceed
    jz short fileOpen
    cmp al, "?"
    je short .error
    cmp al, "*"
    jne short .mainlp
.error:
    lea rdx, badDrvStr
    jmp badExitMsg
;Now we open the file to check if it exists and if it does, if it is readonly
fileOpen:
;first set the handles to -1
    mov dword [readHdl], -1 ;Init the handles to -1
    lea rdx, pathspec
    mov ecx, dirIncFiles
    mov eax, 4E00h  ;Find First 
    int 41h
    jc short .fileNotFound
;Check if file is read only
    mov eax, 2F00h  ;Get a pointer to the DTA in rbx
    int 41h
    test byte [rbx + ffBlock.attribFnd], dirReadOnly
    jz short .notReadOnly
;Read only files here
    mov byte [roFlag], -1   ;Set read only flag!
.notReadOnly:
;File exists, lets rename it to have a .BAK extension
    lea rsi, pathspec
    lea rdi, bkupfile
    call strcpyASCIIZ
    push rsi
    push rdi
    mov rdi, qword [fileExtPtr] ;Get the pointer to the extension
    add rdi, pspecLen   ;Now make it an offset into the new buffer
    mov dword [rdi], "BAK"  ;Change it into a BAK,0 file
    pop rdi
    pop rsi
    mov eax, 5600h
    int 41h
    jnc short .backupMade
    lea rdx, badBkupStr
    jmp badExitMsg
.backupMade:
;File renamed to backup!

.fileNotFound:
;Maybe new file? Check reason for error! If FNF, its good!
    cmp ax, errFnf  ;If its a file not found error, then we are good!
    lea rdx, badOpenStr ;We can't open the file for whatever
    jne badExitMsg
;Error was file not found so we can make the file!
    mov byte [newFileFlag], -1  ;Set the new file flag!
    
exitOk:
;Let DOS take care of freeing all resources
    mov eax, 4C00h
    int 41h

;----Bad Exits----
badParmExit:
    lea rdx, badParm    ;Bad number of parameters
badExitMsg:
    test rdx, rdx   ;Check if null ptr => Dont print on exit
    jz short .noPrint
    mov eax, 0900h
    int 41h
.noPrint:
    mov eax, 4CFFh
    int 41h
