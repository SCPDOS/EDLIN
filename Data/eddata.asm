;Treat line numbers as dwords even though they are words

roFlag      db 0    ;Flag is set if file is read-only. Cannot edit the file.
noEOFCheck  db 0    ;Flag is set if we are to ignore ^Z chars found in the file

;File editor state information
eofReached  db 0    ;When we reach EOF for file, set to -1

memPtr      dq 0    ;Ptr to the memory arena given by DOS
arenaSize   dd 0    ;Size of the arena
memInUse    dd 0    ;Number of bytes in use
;If arenaSize = memInUse, refuse any "extensionary" instructions.
; Allow searching, editing, flushing, editing up to equal 
; number of chars in line.

linePtr     dq 0    ;Ptr to the current source line in memory
lastLine    dd 0    ;Last line number currently in memory