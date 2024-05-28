;WE SET ALL VARS TO 0 ON STARTUP!

pathSep     db ?    ;Default \, Alternative /
switchChar  db ?    ;Default /, Alternative -
roFlag      db ?    ;Flag is set if file is read-only. Cannot edit the file.
newFileFlag db ?    ;Flag indicating the file being made is new (when set, above flag meaningless)
noEofChar   db ?    ;Flag is set if we are not to check for ^Z chars found in the file
eofReached  db ?    ;When we reach EOF for file on disk, set to -1, else 0

;Memory Related variables
arenaSize   dd ?    ;Size of the arena in bytes 
freeCnt     dd ?    ;Count of 1/4 of the arena in bytes (for write)
memPtr      dq ?    ;Ptr to the memory arena given by DOS
fillPtr     dq ?    ;Ptr to 3/4 of the arena in bytes (for append)

;Editor state vars!
curLineNum  dw ?    ;Word value for the current line number (1 based)
curLinePtr  dq ?    ;Pointer to the current line
eofPtr      dq ?    ;Pointer to the EOF char in the buffer
endOfArena  dq ?    ;Ptr to the last available byte in the arena

modFlag     db ?    ;Flag set to indicate the file was modified
;Backup is only deleted on exit or write, to make space for temp file.
bkupDel     db ?    ;Flag to indicate that the backup was deleted

;Don't jiggle these symbols, need dword to be together for -1
readHdl     dw ?    ;Contain the file handle for the open file
writeHdl    dw ?    ;Handle to the temporary file

pathspec    db 128 dup (?)  ;Space for the 128 byte buffer for full filename
wkfile:                     ;Ptr to below path for "working" file
bkupfile    db 128 dup (?)  ;Pathspec for backup file 

tmpNamePtr:         ;Ptr to the filename in the commandtail
fileNamePtr dq ?    ;Ptr to the name portion of filespec
tmpNamePtr2:        ;Ptr to the end of the command in the commandtail
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
;The above pointers point past the dot or pathseperator
;Both file*ptr's point to elements on WKFILE not pathspec

;Command line variables
cmdLine     db halfLine_size dup (?)
;Arguments for parsing
charPtr     dq ?    ;Ptr to char for continuing processing
argCnt      db ?    ;Count of arguments in parsed command line
;Arguments are converted to signed words where appropriate
; and parsed into here in the order they are encountered in.
;
;Any arguments which mean 0 wrt line numbers means current line
argTbl:
arg1        dw ?
arg2        dw ?
arg3        dw ?
arg4        dw ?
qmarkSet    db ?    ;Set if question mark encountered
argString   db halfLine_size dup (?)    ;Used by search and replace only

noAppendErr db ?    ;Special init var, prevents append errors for initial load

;The workline gets preloaded with the original line before editing
workLine    db 258 dup (?)  ;Line in which all editing takes place
workLen     dd ?            ;Line length before edit
spareLine   db 258 dup (?)  ;Spare editing line

xfrName     db 128 dup (?)  ;Transfer name buffer
xfrHdl      dw ?

movCpFlg    db ?    ;Set if move, clear if copy
blkPtrSrc   dq ?    ;Ptr to the line which starts the copy
blkPtrEnd   dq ?    ;Ptr to the line after the range we will copy
cpyPtrDest  dq ?    ;Ptr to the line we will be copying to
blkSize     dd ?    ;This is the size of the unit to move (cpySize)
copySize    dd ?    ;This is the number of bytes we will copy (cpyLen)