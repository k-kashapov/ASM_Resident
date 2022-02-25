.186
.model tiny
.code
org 100h

STAYRES macro                           ; terminates the program and keeps it resident
        mov AX, 3100h
        mov DX, offset DataEnd          ; save in DX the amount of paragraphs needed
        add DX, 15d                     ; DX += 15 in case right shift drops any neccessary bits off
        shr DX, 04h                     ; paragraph = 16 bytes
        int 21h
endm

KBRD_ACK macro
        in  AL, 60h                     ; flashes to kbrd ctrl with eldest bit
        mov AH, AL                      ; save last read scancode byte to AH
        or  AL, 80h                     ; 0....b -> 1....b
        out 61h, AL                     ; send changed byte to kbrd ctrl
        mov AL, AH                      ; AL = saved Byte
        out 61h, AL                     ; send original byte to kbrd ctrl
endm

EOI     macro
        mov AL, 20h
        out 20h, AL
endm

SCR_WIDTH equ 160d		        ; screen width in bytes
WP        equ WORD PTR

_start:
        mov OldDS, DS                 ; Save data segment to variable

        xor BX, BX
        mov ES, BX                      ; ES = 0000h

        mov BX, 09h * 4                 ; 9th cell of int table

        mov DI, offset Old09
        
        mov AX, WP ES:[BX]              ; Save old int addr to AX
        mov [DI], AX                    ; Save it to Old09 lower 2 bytes

        mov AX, WP ES:[BX + 2]          ; Save old int seg to AX
        mov [DI + 2], AX                ; Save seg to Old09 elder 2 bytes

        cli                             ; Forbid interrupts
                                        ; Put our own Seg:Addr into int table
        mov WP ES:[BX], offset Res09    ; Addr
        
        mov AX, CS                      ; Segment
        mov WP ES:[BX + 2], AX

        sti                             ; Allow interrupts

        STAYRES


;##############################################
; Draws a line on the screen
;
; Expects: 
;	AH - Color of the line
;	CX - Length of the line
; 	SI - addr of 3-byte line style array
;	BX = DI - addr of start of line
;
; Note:
;	ES = videoseg addr (0b800h)
;	BX += number of empty lines * width of the line
;
; Returns:  
;       None
;##############################################

DrawLine proc
				; UL corner
	lodsb			; ld byte from [si] to al
	stosw			; mov al to es:[di]
	
        jcxz @@Ret

	lodsb			; U prt
	rep stosw	        ; repeat stosw while cl > 0

	lodsb			; TR corner
	stosw

@@Ret:
	add bx, SCR_WIDTH	; bx = rows offset
	ret
endp

;==============================================
; Our resident function
;==============================================

Res09   proc
        push AX BX CX DI DS ES SI

        db 0B8h                         ; mov AX, ... <-- we'll put here data segment
OldDS   dw 0                            ; for correct offset

        mov DS, AX

        mov AX, 0B800h                  ; Save video segment to ES
        mov ES, AX

        mov DI, 39d * 2d                ; 39th symbol, 1st row
        mov BX, DI
        mov AH, 4Eh                     ; blue on white

        mov SI, offset BRD              ; border symbols array
        mov CX, 39d

        call DrawLine

        in  AL, 60h                     ; read from keyboard buffer
        stosw                           ; print to screen

        pop SI ES DS DI CX BX AX

LONGJMP db 0EAh
Old09   dd 0

        iret
endp

Regs    db 'AX: BX: CX: DX: '
LastKey db 00h
BRD     db '123'

DataEnd:
end _start
