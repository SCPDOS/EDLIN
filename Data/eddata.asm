;This version can only deal with files of max 64Mb in size.
;No line length maximum (Unless your line is 64Mb in size)
;It suffices to work with the DOS kernel!

roFlag      db 0    ;Flag is set if file is read-only. Cannot edit the file.
noEOFCheck  db 0    ;Flag is set if we are to ignore ^Z chars found in the file
switchChar  db "/"


currOff     dq 0    ;Offset in file of the START of the window we are editing
memPtr      dq 0    ;Ptr to the memory arena given by DOS
bufferPtr   dq 0    ;Ptr to the buffer for the current line
bufferSize  dd 0    ;Mustnt exceed 1024*1024*8 bytes (8Mbytes)