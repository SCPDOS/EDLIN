;Initialised data goes here :)

;The following three tables are connected. Don't jiggle!
cmdLetterTable:
    db CR,";ACDEILPMQRSTW"
    cmdLetterTableL equ $ - cmdLetterTable
cmdFcnTable:
    dw editLine - cmdFcnTable
    dw editLine - cmdFcnTable
    dw appendLines - cmdFcnTable
    dw copyLines - cmdFcnTable
    dw deleteLines - cmdFcnTable
    dw endEdit - cmdFcnTable
    dw insertLine - cmdFcnTable
    dw listLines - cmdFcnTable
    dw pageLines - cmdFcnTable
    dw moveLines - cmdFcnTable
    dw quit - cmdFcnTable
    dw replaceText - cmdFcnTable
    dw searchText - cmdFcnTable
    dw transferLines - cmdFcnTable
    dw writeLines - cmdFcnTable
cmdRoTable:
;Byte set if we can do this command in RO mode
    db 0    ;Insert
    db 0    ;Insert
    db -1   ;Append
    db 0    ;Copy
    db 0    ;Delete
    db 0    ;End (save changes)
    db 0    ;Insert
    db -1   ;List
    db -1   ;Page
    db 0    ;Move
    db -1   ;Quit (no save)
    db 0    ;Replace
    db -1   ;Search
    db 0    ;Transfer 
    db -1   ;Write