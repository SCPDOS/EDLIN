;Edlin Strings are in this file
newStr  db "New file",CR,LF,"$"
eofStr  db "End of input file",CR,LF,"$"    ;When EOF occurs
badVerStr   db "Invalid DOS Version",CR,LF,"$"
badDrvStr   db "Invalid Drive or filename",CR,LF,"$"
badNameStr  db "File name must be specified",CR,LF,"$"
badCreatStr db "Cannot create specified file",CR,LF,"$"
badOpenStr  db "Cannot open specified file",CR,LF,"$"
badFileStr  db "Cannot parse sepcified filespec",CR,LF,"$"
badBackDel  db "Access denied - Backup file not deleted",CR,LF,"$"
badParm     db "Invalid Parameter",CR,LF,"$"
badInput    db "Entry error",CR,LF,"$"
badRealloc  db "Reallocation error",CR,LF,"$"
badMemSize  db "Not enough memory to load file", CR,LF,"$"
badFileExt  db "Cannot edit .BAK file--rename file",CR,LF,"$"
badROcmd    db "Invalid operation: R/O file",CR,LF,"$"
badDskFull  db "Disk full-- write not completed$"
badRead     db "Bad read of input file. Aborting...",CR,LF,"$"
exitQuit    db "Abort edit (Y/N)? $"
okString    db "O.K.? $"