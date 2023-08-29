pathsepChar db ?    ;Default \, Alternative /
switchChar  db ?    ;Default /, Alternative -

;All variables that dont need initialisation go here
roFlag      db ?    ;Flag is set if file is read-only. Cannot edit the file.
newFileFlag db ?    ;Flag indicating the file being made is new (when set, above flag meaningless)
noEofCheck  db ?    ;Flag is set if we are not to check for ^Z chars found in the file
eofReached  db ?    ;When we reach EOF for file on disk, set to -1, else 0

;Memory Related variables
memPtr      dq ?    ;Ptr to the memory arena given by DOS
arenaSize   dd ?    ;Size of the arena in bytes (rounded up to nearest 256 byte boundary)
numLines    dw ?    ;Number of 256 byte lines in the arena (arena size / 256 bytes)

tmpNamePtr:         ;Ptr to the filename in the commandtail
fileNamePtr dq ?    ;Ptr to the name portion of filespec
tmpNamePtr2:        ;Ptr to the end of the command in the commandtail
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
;The above pointers point past the dot or pathseperator

;Don't jiggle these symbols, need dword to be together for -1
readHdl:            ;Symbol for the same file
fileHdl     dw ?    ;Contain the file handle for the open file
writeHdl:           ;Symbol for the same file
tmpHdl      dw ?    ;Handle to the temporary file

fcbBuffer:
tmpName     db 20 dup (?)   ;Space for the ASCIIZ path for tmp name.
;                              names of the form ".\12345678.ext",0
pathspec    db 128 dup (?)  ;Space for the 128 byte buffer for full filename
pspecLen    equ $ - pathspec    ;Used to compute the difference between portions.
bkupfile    db 128 dup (?)  ;Pathspec for backup file!

;Command line variables
cmdLine     db halfLine_size dup (?)
args        db ?    ;Count of arguments in parsed command line
cmdChar     db ?
;Arguments are converted to signed words where appropriate
; and parsed into here in the order they are encountered in.
;
arg1        dw ?
arg2        dw ?
arg3        dw ?
arg4        dw ?
argString   db halfLine_size dup (?)    ;Used by search and replace only
argPastEnd  db ?    ;0 -> normal, -1 -> Offset from end of mem (indicated by #)

;The editLine gets preloaded with the original line before editing
;editLine has type "line"
editLine    db 256 dup (?)  ;Line in which all editing takes place
