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
;No command line arguments except for optional filename
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
    mov qword [fileNamePtr], rdi    ;Save the ptr to the filename
    inc rdi ;Go back where it was
.findEndLoop:
    lodsb
    cmp al, SPC
    je short .endFound
    cmp al, CR
    je short .endFound
    dec ecx
    jz short badExitMsg
.endFound:
    dec rdi
    xor eax, eax
    mov byte [rdi], al  ;Store terminating NULL
;Now go backwards a max of 3 chars to get a ptr to the 
; extension of the filename if one exists. If not, create an empty extension.

    mov rdi, qword [fileNamePtr]
    mov ax, word [rdi]  ;Get the first two chars of file name
    cmp ah, ":"
    jne short .noDriveSpecified
    ;Check if drive specified is OK, bl has signature
    lea rdx, badDrvStr
    cmp bl, -1
    je badExitMsg
.noDriveSpecified:
;Paths can only be a max of 67 chars but the DTA buffer is 127 bytes
; so if no extension is provided or too short an extension is provided,
; simply add space for the extension.
;-----------------------It is nice to dream big-----------------------
;Now we proceed with opening the file/creating if it is new.

;If the file is new, create with $$$ extension. Goto End.
;Else, check if there is a backup by replacing the extension with .BAK.
;If so, delete the backup.
;Rename the current file to have a .BAK extension.
;Open the Backup.
;Now change the filename to have a $$$ extension.
;Open the new version.
;Copy the whole backup into the buffer.
;Close the backup.
;End:
;Process file. On exit, close the handle.
;Rename file to have the original (potentially empty) extension.
;Return to DOS
;-----------------------It is nice to dream big-----------------------
; Now we proceed with creating the file if it is new or opening if not

    mov rdx, rdi    ;Get the file name pointer
    mov eax, 3D02h  ;Open in R/W mode
    int 41h
    jnc short .fileOpen
    cmp al, errFnf
    je short .createFile
    lea rdx, badOpenStr
    jmp badExitMsg
.createFile:
    mov eax, 3C00h  ;Create file
    xor ecx, ecx    ;Regular attributes 
    int 41h
    jnc short .fileOpen
    lea rdx, badCreatStr
    jmp badExitMsg
.fileOpen:
    mov word [fileHdl], ax  ;Save the handle for access whenever

;Now get the attribs of the file (rdi points to the filename)
    mov eax, 4300h  ;CHMOD get attribs
    int 41h
    and cl, fileRO   ;Save only the RO bit
    jz short .notRO
    mov byte [roFlag], -1   ;Set Read Only bit on
.notRO:
    

exitOk:
;Let DOS take care of freeing all resources
    mov eax, 4C00h
    int 41h


