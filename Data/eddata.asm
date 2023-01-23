;This version can only deal with 65536 line of maximum 128 length each.
;This amounts to files of roughly 8Mb in size which is large enough for now.
;It suffices to work with the DOS kernel!

fileNamePtr dq 0    ;Ptr to the name of the file we are editing
fileExtPtr  dq 0    ;Ptr to the extension of the file we are editing
fileHdl     dw 0    
bkupExt     db 3 dup (SPC)    ;3 chars to save a given extension if one given

currentLine dw 0    ;Ctr for the current line we are on. 65536 Lines possible
linePtr     dq 0    ;Ptr to the current line start

;Use a single buffer. For now, if less than 8Mb available, just don't load
bufferPtr   dq 0    ;Ptr to the buffer for the current line
bufferSize  dd 0    ;Mustnt exceed 1024*1024*8 bytes (8Mbytes)