;All variables that dont need initialisation go here
tmpNamePtr:
fileNamePtr dq ?    ;Ptr to the name portion of filespec
fileExtPtr  dq ?    ;Ptr to the extension of the file we are editing
fileHdl     dw ?    ;Contain the file handle for the open file

tmpName     db 16 dup (?)   ;Space for the ASCIIZ path for tmp name.
;                              names of the form ".\12345678.ext",0
pathspec    db 128 dup (?)  ;Space for the 128 byte buffer for full filename
pathspec2   db 128 dup (?)  ;Second pathspec space
bkupExt     dd ?    ; A backup for a .EXT to be used (dot included!!!)
