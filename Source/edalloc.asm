;This file contains the memory and structure handling routines.

;The deal with allocating and freeing of resources on the OS side,
; and ensuring we dont use more memory than is strictly necessary
; to host our file + edits.
;On the edlin side, it deals with keeping track of linkages between
; various structures such as lineMemArenas and stringMemArenas and
; lines and strings themselves.

flushLine:
;1) Flushes the string to disk.
;2) Resets the dirty flag in the line if this succeeded

deallocateLine:
;1) Flushes the string to disk.
;2) Deallocates the string.
;3) Marks the line as free.
;4) Decrements the .dCount value
;5) If .dCount = 0, frees the arena and exit. Else, just exit.


incAllocCount:
;When a new line is added, we increment the allocation count.
;If after alloc we get to dMaxAlloc for this arena, we allocate
; a new arena by calling makeArena

freeAlloc:
;Frees the arena back to DOS

makeAlloc:
;If it fails, may need to return to main loop with error that 
; data needs to be flushed to disk.

findFreeStringSpace:
findFreeLineSpace:
;When searching for a new line, first search for a 
; free line. If no free line in arena, goto next arena. If no more 
; arenas, attempt to makeAlloc. If makeAlloc fails, search
; for lines that are not dirty and use the first one found. If none,
; return to main with error that 

findFreeSpace:
;This is the common core of the find free resource function