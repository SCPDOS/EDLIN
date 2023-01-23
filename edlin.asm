[map all ./Listings/edlin.map]
[DEFAULT REL]
BITS 64
;EDLIN, an absolute last resort file editor.
;
;                       !!DONT FORGET!!
;       Each line is terminated first with 0Dh then 0Ah (CR,LF)
;                       !!DONT FORGET!!
;
;The logic of this EDLIN will be based on my BASIC interpreter editor.
;Except, users won't need to specify their own line numbers each time.

;Edlin will always produce a backup file and refuses to open files 
; with .BAK extension (backup files)

;Edlin will erase the previous backup if one exists, ensuring there
; is enough free space for a new copy of the backup.
;It then creates a new file with the specified name and a $$$ extension.

;Edlin has two modes of operation: Command and Edit

%include "./Include/dosMacro.mac"
%include "./Include/edStruc.inc"
Segment .text align=1 
%include "./Source/edmain.asm"
%include "./Source/edutils.asm"
Segment .data align=1 follows=.text 
%include "./Data/eddata.asm"
%include "./Data/edmsg.asm"
Segment .stack align=8 follows=.data nobits
;Use a 200 QWORD stack
    dq 200 dup (?)
stackTop:
endOfProgram:   ;Deallocate from here