;Edlin Strings are in this file 
newStr  db "New file"   ;This string is terminated by the next line
crlf    db CR,LF,"$"
eofStr  db "End of input file",CR,LF,"$"    ;When EOF occurs
badVerStr   db "Invalid DOS Version",CR,LF,"$"
badDrvStr   db "Invalid Drive Specified",CR,LF,"$"
badNameStr  db "File name must be specified",CR,LF,"$"

badInput    db "Entry error",CR,LF,"$"