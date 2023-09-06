pathSep     db ?    ;Default \, Alternative /
switchChar  db ?    ;Default /, Alternative -

;All variables that dont need initialisation go here
roFlag      db ?    ;Flag is set if file is read-only. Cannot edit the file.
newFileFlag db ?    ;Flag indicating the file being made is new (when set, above flag meaningless)
noEofChar   db ?    ;Flag is set if we are not to check for ^Z chars found in the file
eofReached  db ?    ;When we reach EOF for file on disk, set to -1, else 0

;Memory Related variables
memPtr      dq ?    ;Ptr to the memory arena given by DOS
arenaSize   dd ?    ;Size of the arena in bytes 
fillSize    dd ?    ;Size of 3/4 of the arena in bytes
textLen     dd ?    ;Number of chars in the arena
endOfArena  dq ?    ;Ptr to the last byte in the arena
curLinePtr  dq ?    ;Ptr to the start of the current line in arena
curLineNum  dw ?    ;Word value for the current line number

;Don't jiggle these symbols, need dword to be together for -1
readHdl     dw ?    ;Contain the file handle for the open file
writeHdl    dw ?    ;Handle to the temporary file

pathspec    db 128 dup (?)  ;Space for the 128 byte buffer for full filename
wkfile:                     ;Ptr to below path for "working" file
bkupfile    db 128 dup (?)  ;Pathspec for backup file and working .??? file

tmpNamePtr:         ;Ptr to the filename in the commandtail
fileNamePtr dq ?    ;Ptr to the name portion of filespec
tmpNamePtr2:        ;Ptr to the end of the command in the commandtail
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
;The above pointers point past the dot or pathseperator
;Both file*ptr's point to elements on WKFILE not pathspec

;Command line variables
cmdLine     db halfLine_size dup (?)
;Arguments for parsing
charInLine  db ?    ;Offset into cmdLine of char we are studying
argCnt      db ?    ;Count of arguments in parsed command line
cmdChar     db ?    ;Command Letter 
relCur      db ?    ;Tells if rel curline. 0=no, 1=+, -1=-
;Arguments are converted to signed words where appropriate
; and parsed into here in the order they are encountered in.
;
argTbl:
arg1        dw ?
arg2        dw ?
arg3        dw ?
arg4        dw ?
qmarkSet    db ?    ;Set if question mark encountered
argString   db halfLine_size dup (?)    ;Used by search and replace only
argPastEnd  db ?    ;0 -> normal, -1 -> Offset from end of mem (indicated by #)

;The workLine gets preloaded with the original line before editing
;workLine has type "line"
workLine    db 256 dup (?)  ;Line in which all editing takes place
