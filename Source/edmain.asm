;Main EDLIN file
edlinMain:

mainLoop:


exitOk:
;Let DOS take care of freeing all resources
    mov eax, 4C00h
    int 41h


