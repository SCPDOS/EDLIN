;Edlin Strings are in this file
newStr  db "New file"   ;This string is terminated by the next line
crlf    db CR,LF,"$"
eofStr  db "End of input file",CR,LF,"$"    ;When EOF occurs
badVerStr   db "Invalid DOS Version",CR,LF,"$"
badDrvStr   db "Invalid Drive Specified",CR,LF,"$"
badNameStr  db "File name must be specified",CR,LF,"$"
badCreatStr db "Cannot create specified file",CR,LF,"$"
badOpenStr  db "Cannot open specified file",CR,LF,"$"
badDirStr   db "Cannot open directory to edit",CR,LF,"$"
badFileStr  db "Cannot parse sepcified filespec",CR,LF,"$"
badParm     db "Invalid Parameter",CR,LF,"$"
badInput    db "Entry error",CR,LF,"$"
badRealloc  db "Reallocation error",CR,LF,"$"
prompt      db CR,LF,"*$"