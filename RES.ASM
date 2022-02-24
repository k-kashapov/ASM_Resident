.186
.model tiny
.code
org 100h

STAYRES macro                   ; terminates the program and keeps it resident
        mov AX, 3100h
        mov DX, offset DataEnd  ; save in DX the amount of paragraphs needed
        ; add DX, 15d             ; DX += 15 in case right shift drops any neccessary bits off
        shr DX, 04h             ; paragraph = 16 bytes
        inc DX
        int 21h
endm

KBRD_ACK macro
        in  AL, 60h                     ; flashes to kbrd ctrl with eldest bit
        mov AH, AL                      ; save last read scancode byte to AH
        or  AL, 80h                     ; 0....b -> 1....b
        out 61h, AL                     ; send changed byte to kbrd ctrl
        mov AL, AH                     ; AL = saved Byte
        out 61h, AL                     ; send original byte to kbrd ctrl
endm

EOI     macro
        mov AL, 20h
        out 20h, AL
endm

WP      equ WORD PTR

_start:
        xor BX, BX
        mov ES, BX                      ; ES = 0000h

        mov BX, 09h * 4                 ; 9th cell of int table

        mov DI, offset Old09
        
        mov AX, WP ES:[BX]              ; Save old int addr to AX
        mov [DI], AX          ; Save it to Old09 lower 2 bytes

        mov AX, WP ES:[BX + 2]          ; Save old int seg to AX
        mov [DI + 2], AX      ; Save seg to Old09 elder 2 bytes

        cli                             ; Forbid interrupts
                                        ; Put our own Seg:Addr into int table
        mov WP ES:[BX], offset Res09    ; Addr
        
        mov AX, CS                      ; Segment
        mov WP ES:[BX + 2], AX

        sti                             ; Allow interrupts

        STAYRES

;==============================================
; Our resident function
;==============================================

Res09   proc
        push AX DI ES

        mov AX, 0B800h                  ; Save video segment to ES
        mov ES, AX

        mov DI, (80d * 4 + 40d) * 2     ; 40th symbol, 5th row
        mov AH, 4Eh                     ; blue on white

        in  AL, 60h                     ; read from keyboard buffer
        add AL, '0' - 1                 ; numbers to ASCII
        stosw                           ; print to screen

        pop ES DI AX

LONGJMP db 0EAh
Old09   dd 0

        iret
endp

DataEnd:
end _start
