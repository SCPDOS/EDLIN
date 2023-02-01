;All variables that dont need initialisation go here

fileNamePtr dq ?    ;Ptr to the name of the file we are editing
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
fileHdl     dw ?    ;Contain the file handle for the open file
fileHdl2    dw ?    ;Space for a second handle
fileHdl3    dw ?    ;Third handle

currentLine dw ?    ;Ctr for the current line we are on. 65536 Lines possible
linePtr     dq ?    ;Ptr to the current line start in memory

;Internal Buffers
;cLineBuf = The buffered copy of the current line
;editBuf = The edit space of the current line (copied here after being copied to cLineBuf)
cLineBuf    db linelen + 3 dup(?)   ;128 byte buffer + 3 chars for the 41/0Ah metadata
editBuf     db 2*linelen + 3 dup(?)   
