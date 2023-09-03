;This is where the main user selectable routines are
;All arguments specified are signed words

;Arguments above these limits will throw an error and the input
; will be discarded.

appendLines:
;If the file is not fully loaded in arena, allows you to load 
; the next portion into the arena. Reads byte by byte from 
; the file until the desired number of CRLF's have
; been hit (inefficient?) or (appropriate) EOF condition.
;If no n specified, we write the first 1/4 of the arena 
; and shift the rest of the lines up.
;--------------------------------------------
;Invoked by: [n]A (number of bytes to read)
;--------------------------------------------

copyLines:
;Duplicates a line or a range of lines to a position specifed 
;   (non-overlapping) 
;--------------------------------------------
;Invoked by: [line],[line],line[,count]C
;--------------------------------------------

deleteLines:
;Deletes one or a range of lines
;--------------------------------------------
;Invoked by: [line][,line]D
;--------------------------------------------

editLine:
;Displays a line and allows it to be edited
;--------------------------------------------
;Invoked by: [line]
;--------------------------------------------

endEdit:
;Inserts a EOF char at the end of the file if one not already present
; renames the original file (if applicable) to have .bak ending and
; renames the working file to the name originally specified.
;--------------------------------------------
;Invoked by: E
;--------------------------------------------

insertLine:
;Inserts a line
;--------------------------------------------
;Invoked by: [line]I
;--------------------------------------------

listLines:
;Prints a line or a number of lines.
;Defaults to from current line print 23 lines
;--------------------------------------------
;Invoked by: [line][,line]L
;--------------------------------------------

pageLines:
;Prints a page of lines
;Defaults to from current line to print 23 lines
;--------------------------------------------
;Invoked by: [line][,line]P
;--------------------------------------------

moveLines:
;Moves a block of lines elsewhere (non overlapping moves only)
;--------------------------------------------
;Invoked by: [line][line],lineM
;--------------------------------------------

quit:
;Quits EDLIN, not saving work and deleting working file.
;--------------------------------------------
;Invoked by: Q
;--------------------------------------------

replaceText:
;Replaces all matching strings with specified string (NO REGEX)
;--------------------------------------------
;Invoked by: [line][,line][?]R[string][<F6>string]
;--------------------------------------------

searchText:
;Searches text for a string
;--------------------------------------------
;Invoked by: [line][,line][?]S[string]
;--------------------------------------------

transferLines:
;Writes the lines specified to the specified file
;--------------------------------------------
;Invoked by: [line]T[d:]filename
;--------------------------------------------

writeLines:
;Writes the current arena to disk. If no 
; n specified, EDLIN writes lines until
; 1/4 of the arena is free.
;--------------------------------------------
;Invoked by: [n]W (number of bytes to write)
;--------------------------------------------