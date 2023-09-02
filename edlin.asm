[map all ./Listings/edlin.map]
[DEFAULT REL]
BITS 64
;EDLIN, an absolute last resort file editor.
;
;                       !!DONT FORGET!!
;       Each line is terminated first with 0Dh then 0Ah (CR,LF)
;                       !!DONT FORGET!!
;

;Edlin will always produce a backup file and refuses to open files 
; with .BAK extension (backup files)

;Edlin will always terminate a file with a single EOF character

;Edlin will erase the previous backup if one exists, ensuring there
; is enough free space for a new copy of the backup.
;It then creates a new file with the filename with a $$$ extension.
;All edits occur in memory and are flushed to it. We then rename it
; to the desired filename.
;BAK files cannot be opened.
;
;Empty lines are default just a CR,LF pair

;Edlin has two modes of operation: Command and Edit

%include "./Include/dosMacro.mac"
%include "./Include/dosError.inc"
%include "./Include/edStruc.inc"
%include "./Include/dosStruc.inc"
Segment .text align=1 
%include "./Source/edmain.asm"
%include "./Source/edutils.asm"
Segment .data align=1 follows=.text 
%include "./Data/eddata.asm"
%include "./Data/edmsg.asm"
Segment .bss align=1 follows=.data nobits
bssStart:
%include "./Data/edbss.asm"
bssLen equ ($ - bssStart)
Segment .stack align=16 follows=.bss nobits
;Use a 200 QWORD stack
    dq 200 dup (?)
stackTop:
endOfProgram:   ;Deallocate from here