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
;Initialise the BSS to 0
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
    mov byte [switchChar], dl
    mov byte [pathSep], al
getCmdTail:
    mov eax, 6101h  ;Get parsed FCB and cmdtail for filename in rdx
    int 21h
;Now parse the command line, to get full command spec for filename.
    lea rsi, qword [rdx + cmdArgs.progTail]     ;Get ptr to tail
    mov rbp, rdx        ;Save the cmdArgs ptr for use when checking drive ok
cmdTailParse:
    call .skipSeps      ;Skips leading terminators
    cmp al, CR          ;If al is CR, we are done!
    je .parseComplete
    cmp al, byte [switchChar]       ;If al is a switchchar, rsi points to it!
    je .switchFnd
;Else it must be a file name!
    cmp qword [tmpNamePtr], 0
    jnz .parseBadExit   ;If this is not empty, too many filenames specified!
    mov qword [tmpNamePtr], rsi     ;Save the pointer here :)
    call .findSep                   ;Find the end of the filename
    mov qword [tmpNamePtr2], rsi    ;And save it here 
    cmp al, CR                      ;Did we terminate with a CR?
    je .parseComplete               ;If so, we are done!
    jmp short cmdTailParse          ;Else, keep parsing!
.switchFnd:
    inc rsi                 ;Go to the char past the switch
    lodsb                   ;Get the switchchar itself, advance rsi
    and al, ~20h            ;Clear the LC bit from the char
    cmp al, "B"
    jne .parseBadExit
    mov byte [noEofChar], -1   ;Set the internal flag
    lodsb                   ;Now do lookahead
    dec rsi                 ;Get the char rsi is pointing to, after B
    cmp al, CR              ;If this is a CR, we are done!
    je .parseComplete 
    call .isAlSep           ;Is the char after /B a sep?
    jz cmdTailParse         ;If so, keep parsing
.parseBadExit:              ;Else, fallthru to error
    jmp badParmExit
.skipSeps:
;Leaves rsi pointing to the first non-separator char
    lodsb
    call .isAlSep
    jz .skipSeps
    dec rsi     ;Always return to the char itself!
    return
.findSep:
;Leaves rsi pointing to the first found separator char, CR or switchChar
;Input: rsi -> pathspec to find end of
    lodsb
    cmp al, CR
    je .fsExit
    cmp al, byte [switchChar]
    je .fsExit
    call .isAlSep
    jnz .findSep
.fsExit:
    dec rsi
    return
.isAlSep:
;Checks if al is a terminator char. Sets ZF if so.
;Input: al = Char to check.
    cmp al, SPC
    rete
    cmp al, TAB
    rete
    cmp al, ";"
    rete
    cmp al, ","
    rete
    cmp al, "="
    return
.nameBadExit:
    lea rdx, badNameStr
    jmp badExitMsg
.parseComplete:
;Check we have a pointer to a filename AT LEAST.
    cmp qword [tmpNamePtr], 0
    je .nameBadExit
;Now we copy the filename internally.
nameCopy:
    lea rdi, pathspec   ;Store in the pathspec
    mov rsi, qword [tmpNamePtr]
    mov eax, 121Ah  ;Get the file drive, advance rsi if X:
    int 2Fh
    test al, al
    jnz .notCurDrv
    mov eax, 1900h  ;Get the current drive in al
    int 21h
    inc al  ;Turn it into a 1 based number
.notCurDrv:
    mov dl, al  ;Save the 1-based drive letter in dl
    add al, "@" ;Convert into a drive letter
    mov ah, ":"
    stosw   ;Store the drive letter in the buffer, adv rdi by 2
    lodsb   ;Get the first char from the pathspec given...
    dec rsi ;...and go back to this char
    cmp al, byte [pathSep]  ;If this is a pathsep, we have abs path!
    je .cpLp    ;Avoid getting the current directory and copy immediately!
    mov al, byte [pathSep]  ;Get a pathsep
    stosb       ;and store it, incrementing rdi
    push rsi    ;Save the source of chars in the spec now
    mov rsi, rdi
    mov eax, 4700h  ;Get current dir for drive in here
    int 21h
    pop rsi     ;Get back the source of chars 
    jc badDrvExit
    mov eax, 1212h  ;Strlen from char past leading sep, get the length in ecx 
    int 2fh
    dec ecx         ;Drop the terminating null from the count
    add rdi, rcx    ;Go to the terminating null
    mov al, byte [pathSep]
    cmp byte [rdi - 1], al  ;If the char behind is a pathsep, skip doubling!
    je .cpLp
    stosb           ;Store the pathsep over this null, inc rdi
.cpLp:
    movsb   ;Now copy one char at a time
    cmp rsi, qword [tmpNamePtr2]    ;Check if we are equal to end of string ptr
    jne short .cpLp
    xor eax, eax
    stosb   ;Store the null terminating char
;Now we normalise the pathspec
    lea rsi, pathspec
    mov rdi, rsi
    mov eax, 1211h  ;Normalise the pathspec provided
    int 2fh 
;Now we produce a backup/working filespec
    lea rsi, pathspec
    lea rdi, wkfile ;This pathspec always has an extension
    call strcpy
;rbp still has the cmdArgs ptr. Use it here for the fcb!!
    lea rdi, qword [rbp + cmdArgs.fcb1]
    mov eax, 2901h
    int 21h
    cmp al, -1  ;If this is the case, the drive specified is bad!
    je badDrvExit
;Now invalidate tmpNamePtr and tmpNamePtr2
    xor ecx, ecx
    mov qword [tmpNamePtr], rcx
    mov qword [tmpNamePtr2], rcx
    dec ecx
    lea rdi, wkfile
    mov rbx, rdi    ;Save address of head of file name
    xor eax, eax
    repne scasb     ;rdi points past terminating null
    mov rsi, rdi
    std             ;Go in reverse now
.fileNameSearch:
    lodsb
    cmp al, byte [pathSep]  ;Are we at a pathsep?
    je .fileNameOk  ;Yes, stop scanning
    cmp rsi, rbx    ;Are we at the head of the path?
    jne .fileNameSearch ;If not, keep going back
    sub rsi, 2  ;Pretend we are past a pathSep
.fileNameOk:
    add rsi, 2  ;Now point to the first char of the buffer!
    mov qword [fileNamePtr], rsi    ;Save the ptr
    cld         ;Now go forwards!
    mov ecx, 8  ;number of chars to search thru
.extSearch:
    lodsb
    test al, al
    jz .insertExt
    cmp al, "."
    je .extFound
    dec ecx
    jnz .extSearch    
    inc rsi ;Go to the next position so the below works
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
    jz fileOpen
    cmp al, "?"
    je badDrvExit
    cmp al, "*"
    jne .mainlp
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
    mov byte [eofReached], -1   ;Setup that we at eof
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
    lea rdx, badMemFull
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
    test byte [newFileFlag], -1 ;We skip setting the 1/4 and 3/4 markers 
    jnz .newFile
    mov rsi, rax    ;Save the pointer to memory arena in rsi
    xor ecx, ecx    ;Zero the upper 32 bits
    lea ecx, dword [2*ebx + ebx]    ;Multiply ebx by 3 into ecx
    shr ecx, 2  ;Divide by 4 to get # of bytes to default fill by
    mov dword [fillPtr], ecx   ;Save number of bytes to fill arena with
    add qword [fillPtr], rax   ;Turn into offset from start of arena
    shr ebx, 2  ;Divide by 4 to get # of bytes to default free until
    mov dword [freeCnt], ebx   ;Save number of bytes to free from the arena
.newFile:
;Now we setup the edit and command buffers
    mov byte [workLine + line.bBufLen], lineLen
    mov byte [cmdLine + line.bBufLen], halflineLen
    mov word [curLineNum], 1    ;Start at line 1
    mov qword [curLinePtr], rax
    mov byte [rax], EOF ;Store an EOF at the start of the buffer!
    mov qword [eofPtr], rax
;Nice trick, ensure we dont print any errors on append when initially loading the
; file! Since we are appending, we setup as if the user typed in an arg. 
;arg1 is already zero due to BSS zeroing
    mov byte [argCnt], 1    ;Default to one argument! arg1 = 0 means load to 3/4!
    test byte [newFileFlag], -1
    jnz getCommand
    mov byte [noAppendErr], -1
    call appendLines
    mov byte [noAppendErr], 0
getCommand:
    lea rsp, stackTop   ;Reset the stack pointer
    lea rdx, i23h
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
    dec rsi     ;Go back to the first char past the argument
    call skipSpaces ;Skip spaces
    cmp al, "," ;Is the first char the argument separator?
    je .parse
    dec rsi ;Move rsi back to the non comma char
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
nextCmd:
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

;----Bad Exits----
badDrvExit:
    lea rdx, badDrvStr
    jmp short badExitMsg
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
