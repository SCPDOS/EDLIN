
;All variables that dont need initialisation go here
roFlag      db ?    ;Flag is set if file is read-only. Cannot edit the file.
noEofCheck  db ?    ;Flag is set if we are not to check for ^Z chars found in the file
;File editor state information (defaults to 0)
eofReached  db ?    ;When we reach EOF for file, set to -1

;Treat line numbers as dwords even though they are words
memPtr      dq ?    ;Ptr to the memory arena given by DOS
arenaSize   dd ?    ;Size of the arena
memInUse    dd ?    ;Number of bytes in use
;If arenaSize = memInUse, refuse any "extensionary" instructions.
; Allow searching, editing, flushing, editing up to equal
; number of chars in line.

linePtr     dq ?    ;Ptr to the current source line in memory
lastLine    dd ?    ;Last line number currently in memory


tmpNamePtr:
fileNamePtr dq ?    ;Ptr to the name portion of filespec
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
fileHdl     dw ?    ;Contain the file handle for the open file
bkupHdl     dw ?    ;Handle to the backup file

tmpName     db 16 dup (?)   ;Space for the ASCIIZ path for tmp name.
;                              names of the form ".\12345678.ext",0
pathspec    db 128 dup (?)  ;Space for the 128 byte buffer for full filename
pathspec2   db 128 dup (?)  ;Second pathspec space
bkupExt     db 4 dup (?)    ;A backup for a .EXT to be used (dot included!!!)

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
