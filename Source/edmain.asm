;Contains the program loader
start:
    jmp short .cVersion
.vNum:          db 1    ;Main version number, patchable
.cVersion:
    cld
    mov eax, 3000h  ;Get version number
    int 21h
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
;Now move the stack pointer to its new position and reallocate!
    lea rsp, stackTop
    lea rbx, endOfProgram   ;Guaranteed paragraph alignment
    sub rbx, r8 ;Get number of bytes in block
    shr rbx, 4  ;Convert to paragraphs
    inc rbx     ;Add one more paragraph for good measure
    mov eax, 4A00h
    int 21h
    lea rdx, badRealloc
    jc badExitMsg
;One command line argument except for mandatory filename, /B=(binary read)
    mov eax, 3700h
    int 21h
    mov eax, "\"    ;Default pathsep
    mov ecx, "/"    ;Alternative pathsep
    cmp dl, "-"     ;Is the switch char default or alternative?
    cmove eax, ecx  ;Move if alternative
    mov bl, dl  ;Preserve switch char in bl
    mov byte [switchChar], bl
    mov byte [pathSep], al
getCmdTail:
    mov eax, 6101h  ;Get parsed FCB and cmdtail for filename in rdx
    int 21h
;Now parse the command line, to get full command spec for filename.
    lea rdi, qword [rdx + cmdArgs.progTail]     ;Get ptr to tail
    movzx ecx, byte [rdx + cmdArgs.parmList]    ;Get number of chars in cmdline
cmdTailParse:
    mov al, SPC ;Comparing against a space
.searchLoop:
    jecxz .parseComplete    ;If we run out of chars, exit!
    repe scasb  ;Search for the first non-space char
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
    mov byte [noEofChar], -1   ;Set the internal flag
    inc rdi ;Move rdi to the char after the B
    dec ecx ;And decrement count of chars left
    jz short .parseComplete
    jmp short cmdTailParse   ;Now skip next lot of spaces
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
    int 21h
    jnc short .nameGood ;Name ok, proceed
    cmp al, errBadDrv
    jne short .genericError
    lea rdx, badDrvStr
    jmp badExitMsg
.genericError:
    lea rdx, badFileStr ;If this fails, bad filespec
    jc badExitMsg  ;The filename is bad for some reason!
.nameGood:
;Now we produce a backup/working filespec
    lea rsi, pathspec
    lea rdi, wkfile ;This pathspec always has an extension
    call strcpyASCIIZ
;Now invalidate tmpNamePtr and tmpNamePtr2
    xor ecx, ecx
    mov qword [tmpNamePtr], rcx
    mov qword [tmpNamePtr2], rcx
    dec rcx
    lea rdi, wkfile
    xor eax, eax
    repne scasb   ;rdi points past terminating null
    ;Find the nearest pathsep (since we have fully qualified the name)
    std
    movzx eax, byte [pathSep]   ;Get pathsep char in al
    repne scasb
    cld
    add rdi, 2  ;Point rdi to first char past the pathsep
    mov qword [fileNamePtr], rdi    ;Save the ptr
    mov rsi, rdi
    mov ecx, 8  ;number of chars to search thru
.extSearch:
    lodsb
    test al, al
    jz short .insertExt
    cmp al, "."
    je short .extFound
    dec ecx
    jnz short .extSearch    ;Impossible edgecase (TRUENAME returns 8.3 filename)
.insertExt:
    ;rsi points just past the null
    mov byte [rsi - 1], "." ;Store a pathsep
    mov dword [rsi], "   "   ;Store empty extension so no accidental BAK issues.
.extFound:
    mov qword [fileExtPtr], rsi
;Now we have all the metadata for the filename we are working with
    mov eax, dword [rsi]
    cmp eax, "BAK"  ;Is this a bakup file?
    lea rdx, badFileExt
    je badExitMsg   ;If yes, error!
    mov dword [rsi], "$$$"   ;Now we store working file $$$ extension 
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
;Now we search for the file
    lea rdx, pathspec
    mov ecx, dirIncFiles
    mov eax, 4E00h  ;Find First 
    int 21h
    jc .fileNotFound
;Check if file is read only
    mov eax, 2F00h  ;Get a pointer to the DTA in rbx
    int 21h
    movzx eax, byte [rbx + ffBlock.attribFnd]
    test al, dirReadOnly
    jz short .notReadOnly
.readOnly:
;Read only files here
    mov byte [roFlag], -1   ;Set read only flag!
.notReadOnly:
;File exists, lets open it, to read from
    mov eax, (3Dh << 8) | ReadAccess | denyWriteShare
    lea rdx, pathspec    ;Get the pointer to the working filename
    int 21h         ;Open the file
    jnc short .backupOpened
;File failed to open
    lea rdx, badOpenStr
    jmp badExitMsg
.backupOpened:
;Backup opened and handle in ax.
    mov word [readHdl], ax  ;Store the read handle here
    jmp short createWorkingFile
.fileNotFound:
;Maybe new file? Check reason for error! If FNF, its good!
    cmp ax, errFnf  ;If its a file not found error, then we are good!
    lea rdx, badOpenStr ;We can't open the file for whatever reason
    jne badExitMsg
;Error was file not found so we can make the file!
    mov byte [newFileFlag], -1  ;Set the new file flag!
createWorkingFile:
;Now open a new file with triple question mark extension
;rdi -> Path to file with $$$ (the working file)
    lea rdx, wkfile    ;Get a pointer to this filename
    mov eax, 5B00h  ;Create file (atomic), prevent two edlins from editing same file
    xor ecx, ecx    ;Clear all file attributes (normal file)
    int 21h
    lea rdx, badCreatStr    ;Creating the working file will fail if already exits
    jc badExitMsg   ;This prevents someone from overriding the file
    mov word [writeHdl], ax ;Store a pointer to the write handle
    test byte [newFileFlag], -1 ;If set, this is a new file!
    jz short .notNewFile
    lea rdx, newStr
    mov eax, 0900h
    int 21h
.notNewFile:
;Now the following:
;1) Allocate max memory (1Mb max)
;2) If new file, goto 4. Print "new file" message
;3) Else, fill up to 75% of arena according to table. If 
;    EOF reached (either due to no bytes left or ^Z (if enabled))
;    print "EOF reached message".
;4) Install Int 23h handler
;5) Goto main loop
allocateMemory:
    xor ebx, ebx
    mov ebx, 10000h ;Start trying to allocate at 1Mb
    mov eax, 4800h
    int 21h
    jnc short .loadProgram
    ;If the allocation failed, eax has max paragraphs
    cmp eax, 10h    ;If we have less than 256 bytes available, fail
    jb short .notEnoughMem
    mov ebx, eax    ;Get the number of paragraphs into ebx for request
    mov eax, 4800h
    int 21h
    jnc short .loadProgram
.notEnoughMem:
    lea rdx, badMemSize
    jmp badExitMsg
.loadProgram:
;rax has pointer here
    mov qword [memPtr], rax
    mov rsi, rax
    shl ebx, 4  ;Multiply by 16 to get number of bytes
    add rsi, rbx
    dec rsi     ;Point rsi to the last char of the arena
    mov qword [endOfArena], rsi
    mov dword [arenaSize], ebx  ;Save number of bytes in arena here
    mov rsi, rax    ;Save the pointer to memory arena in rsi
    xor ecx, ecx    ;Zero the upper 32 bits
    lea ecx, dword [2*ebx + ebx]    ;Multiply ebx by 3 into ecx
    shr ecx, 2  ;Divide by 4 to get # of bytes to default fill by
    mov dword [fillSize], ecx   ;Save number of bytes to fill arena with
    shr ebx, 2  ;Divide by 4 to get # of bytes to default free until
    mov dword [freeSize], ebx
    test byte [newFileFlag], -1 ;If this is set it is a new file, skip
    jnz short initBuffers
    mov rdx, rax    ;Move the arena pointer into rdx
    mov eax, 3F00h
    movzx ebx, word [readHdl]  
    int 21h ;If it reads, it reads, if not, oh well.
;Check now for EOF and setup end of text pointer
    mov dword [textLen], eax  ;Save number of chars read into eax
    cmp ecx, eax    ;If less bytes than ecx were read, EOF condition
    jne short .eofFound
    test byte [noEofChar], -1   ;Avoid searching for ^Z?
    jz short initBuffers
    call searchTextForEOFChar
    jnz short initBuffers
.eofFound:
;Now we print the EOF message
    lea rdx, eofStr
    mov eax, 0900h
    int 21h
    mov byte [eofReached], -1   ;Set that we are at the EOF
initBuffers:
;Now we setup the edit and command buffers
    mov byte [workLine + line.bBufLen], lineLen
    mov byte [cmdLine + line.bBufLen], halflineLen
    mov word [curLineNum], 1    ;Start at line 1
getCommand:
    lea rsp, stackTop   ;Reset the stack pointer
    lea rdx, i43h
    mov eax, 2523h  ;Set Interrupt handler for Int 23h
    int 21h
    mov eax, prompt
    call printChar
    lea rdx, cmdLine
    mov eax, 0A00h  ;Take buffered input.
    int 21h
    call printLF 
    lea rsi, qword [cmdLine + halfLine.pString] ;Point to the text of the line
    mov qword [charPtr], rsi
;Now we parse the command line!
;NOTE: Multiple commands may be on the same command line.
;Commands are terminated by a command letter (except in the
; case of S and R where they may be followed by a string).
;If we encounter a CR in the string parsing, then we are
; finished with this command line. Else, we keep parsing the
; same command line, until all the chars in the buffer 
; have been processed and/or a CR has been hit.
parseCommand:
    xor eax, eax
    mov byte [argCnt], al
    mov qword [argTbl], rax ;Clear the argument table
    mov byte [qmarkSet], al
    mov rsi, qword [charPtr]    ;Get rsi to the right place in command line
    lea rbp, argTbl
.parse:
    inc byte [argCnt]   ;Parsing an argument
    call parseEntry ;Returns in bx the word to store in the arg table
    movzx edi, byte [argCnt]
    dec edi ;Turn into offset
    mov word [rbp + 2*rdi], bx  ;Store the argument
    dec rsi ;rsi points at the first char past the argument
    call skipSpaces ;Skip the spaces, rsi points at the first non space char
    cmp al, "," ;Is the first char the argument separator?
    jne short .notSep
    inc rsi ;Keep rsi ahead because ...
.notSep:
    dec rsi ;Move rsi back to the first non-space char
    cmp byte [argCnt], 4
    jb short .parse
    call skipSpaces
    cmp al, "?"
    jne short .notQmark
    mov byte [qmarkSet], -1
    call skipSpaces ;Get the next char (must be a cmd char) in al
.notQmark:
    cmp al, "a"
    jb short .noUC
    and al, 0DFh    ;Convert cmd char to upper case if LC 
.noUC:
    lea rdi, cmdLetterTable
    mov ecx, cmdLetterTableL
    repne scasb
    jne printComErr ;Print an error if char not in table
    not ecx ;1's compliment to subtract 1 too
    add ecx, cmdLetterTableL    ;Get L->R offset into table
;Now check the R/O permissions for the selected function
;ecx has the offset into the table
    test byte [roFlag], -1  ;If this flag is not set, ignore r/o
    jz short execCmd
    lea rbp, cmdRoTable
    test byte [rbp + rcx], -1   ;Test the flag
    jnz short execCmd
    lea rdx, badROcmd
    mov eax, 0900h
    int 21h
    jmp printComErr
execCmd:
    mov qword [charPtr], rsi
    lea rbp, cmdFcnTable
    movsx rbx, word [rbp + 2*rcx]    ;Get word ptr into rbx
    add rbx, rbp    ;Convert the word offset from cmdFcnTbl to pointer
    call rbx
    mov rsi, qword [charPtr]
    call skipSpaces ;Now move to the "following command" or CR
    cmp al, CR
    je getCommand   ;If CR, end of line. Get new command
    cmp al, EOF
    je short .eocChar
    cmp al, ";"
    jne short .skipEocChar
.eocChar:
    inc rsi ;Move rsi ahead one to avoid the below...
.skipEocChar:
    dec rsi ;Move rsi back to the first char of the new command
    mov qword [charPtr], rsi    ;Save the command line pointer
    jmp parseCommand
    
exitOk:
;Let DOS take care of freeing all resources
    mov eax, 4C00h
    int 21h

;----Bad Exits----
badParmExit:
    lea rdx, badParm    ;Bad number of parameters
badExitMsg:
    test rdx, rdx   ;Check if null ptr => Dont print on exit
    jz short badExit
    mov eax, 0900h
    int 21h
badExit:
    mov eax, 4CFFh
    int 21h
