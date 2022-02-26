.186
.model tiny
.code
org 100h

locals @@

STAYRES macro                           ; terminates the program and keeps it resident
        mov AX, 3100h
        mov DX, offset DataEnd          ; save in DX the amount of paragraphs needed
        add DX, 15d                     ; DX += 15 in case right shift drops any neccessary bits off
        shr DX, 04h                     ; paragraph = 16 bytes
        int 21h
endm

KBRD_ACK macro
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

CUR_INT = 08h * 4                       ; addr of the int to save. Init val = 08h = Time Int
INT_BUF equ Old08                       ; name of the buf to save old int to

SAVE_INT macro                          ; saves int at [CUR_INT], [CUR_INT + 2] to INT_BUF
        mov BX, CUR_INT                 ; curr cell of int table

        mov DI, offset INT_BUF          ; DI = &OldInt
        
        mov AX, WP ES:[BX]              ; Save old int addr to AX
        mov [DI], AX                    ; Save it to OldInt's lower 2 bytes

        mov AX, WP ES:[BX + 2]          ; Save old int seg to AX
        mov [DI + 2], AX                ; Save seg to OldInt's eldest 2 bytes
endm

SCR_WIDTH equ 160d		        ; screen width in bytes
WP        equ WORD PTR

_start:
        xor BX, BX
        mov ES, BX                      ; ES = 0000h

        SAVE_INT                        ; save int 08h
        
        cli                             ; Forbid interrupts
                                        ; Put our own Seg:Addr into int table

        mov WP ES:[BX], offset Res08    ; Addr

        mov AX, CS                      ; Segment
        mov WP ES:[BX + 2], AX

        sti                             ; Allow interrupts

        CUR_INT = 09h * 4               ; = 09h = kbrd int
        INT_BUF equ Old09               ; buf for old int 09h
        SAVE_INT                        ; save int 09h

        cli                             ; Forbid interrupts
                                        ; Put our own Seg:Addr into int table

        mov WP ES:[BX], offset Res09    ; Addr

        mov AX, CS                      ; Segment
        mov WP ES:[BX + 2], AX

        sti                             ; Allow interrupts

        STAYRES                         ; Terminate and stay resident

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
;       SI += 3
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
	add BX, SCR_WIDTH	; bx = rows offset
	ret
endp

;==============================================
; Converts integer value into a string, base 16
; Expects:
;       DX - Integer value
;       SI - Buffer to write str into
;       DS - Buffer segment
; Returns:
;       SI - Result string
;==============================================

itoa16  proc
        pusha                           ; save all registers
        mov DI, SI                      ; save init SI value
        add SI, 3                       ; save space for significant bytes: _ _ _ _ SI: _ h

@@BitLoop:
        mov BX, 0Fh                     ; mask = 0..01111b

        and BX, DX                      ; apply mask to DX
        shr DX, CL                      ; cut off masked bits: 01010011b -> 00101|0011b

        mov BL, BYTE PTR DS:[BX + offset HEX]
        mov BYTE PTR DS:[SI], BL

        dec SI                          ; moving backwards: _ _ DI: _ 0 1 0 $
        cmp SI, DI                      ; check if all bytes have been printed
        ja  @@BitLoop

        popa                            ; reset all registers
        ret
endp

;##############################################
; Draws str from buffer to the video RAM
; Expects:
;	AH - Color
;	CL - Width
;	DI - Addr to draw to
;	SI - Addr of 3-byte char array
;	RegVal - Buffer
; Note:
;	ES = videoseg addr (0b800h)
;##############################################

DrawStr proc
        lodsb				; load from [si] to al
	stosw				; draw border
		
	push SI				; save si (pointing at the middle elem) to the stack
		
	lodsb
	stosw				; draw empty space

	mov SI, offset RegVal

@@PutC:
	lodsb				; load from array to al
	stosw				; print input str to video RAM
	dec CL
	ja  @@PutC

	pop SI				; return si value

	lodsb				; draw empty space
	stosw

	lodsb				; draw border
	stosw

	add BX, SCR_WIDTH		; iterate row

	ret
endp

;==============================================
; Our resident function
; Registers:
;       AX - Color|symbol
;       BX = DI - Video addr to write into
;       DS - Curr (code) segment
;       ES - Video segment
;       SI - Border buffer
;       CX - Border len
;==============================================

Res08   proc
        cmp CS:ISOn, 00h                ; if frame is off
        je @@NoFrame                    ; do nothing

        push AX BX CX DX DI DS ES SI
        push AX BX CX DX                ; save main registers to stack

        mov AX, CS                      ; set DS to curr code segment
        mov DS, AX

        mov AX, 0B800h                  ; save video segment to ES
        mov ES, AX

        mov DI, CS:CURDI

        mov BX, DI                      ; save offset to BX
        mov AH, 09h                     ; color = blue on black

        mov SI, offset BRD              ; border symbols array
        mov CX, 6d                      ; width
        call DrawLine                   ; draw top line

        mov CH, 4d                      ; num of iterations of the next loop

@@RegLoop:
        mov CL, 4d                      ; reset width
        pop DX                          ; pop AX, BX, CX, DX from stack to DX
        mov DI, BX                      ; move DI to new printing position

        mov SI, offset RegVal           ; buffer to print register value into
        call itoa16                     ; print reg (popped to DX) value to buffer

        mov SI, offset BRD + 3          ; set SI to border chars arr
        call DrawStr                    ; draw reg value
        
        dec CH
        ja  @@RegLoop                   ; repeat 4 times: for each register

        mov DI, BX                      ; set new DI
        mov CX, 6d                      ; bottom line width
        call DrawLine                   ; draw bottom line

        pop SI ES DS DI DX CX BX AX
@@NoFrame:
        db 0EAh                         ; longjmp
Old08   dd 0
endp

RSHIFT  equ 36h
LSHIFTD = 2Ah
LSHIFTU = 2Ah or 80h

Res09   proc
;----------------------------------------------
;       THE FEATURE
;       Allows you to move frame by 
;       pressing Shift + U/D/L/R
;----------------------------------------------
        push ES DI BX AX

        in  AL, 60h                     ; read from kbrd buffer
        cmp AL, RSHIFT                  ; if right shift
        jne @@CheckOn

        not CS:ISOn                     ; turn on/off

@@CheckOn:
        cmp CS:ISOn, 00h                ; if frame is off
        je  @@Fin                       ; do nothing

        cmp AL, LSHIFTD                 ; check if left shift is down
        jne @@CheckLshiftUP

        mov LShDwn, 01h                 ; change L shift flag

@@CheckLshiftUP:
        cmp AL, LSHIFTU                 ; check L shift is released
        jne @@CheckLshift

        mov LShDwn, 00h                 ; if released, turn flag off

@@CheckLshift:
        cmp LShDwn, 00h                 ; check if left shift flag 
        je  @@Fin

@@LShiftDown:
                                        ; else: move it around
        cmp AL, 4Bh                     ; left arrow key
        jne @@RArr
        sub CS:CURDI, 16

        jmp @@NoOldInt 

@@RArr:
        cmp AL, 4Dh                     ; right arrow key
        jne @@UArr

        add CS:CURDI, 16
        jmp @@NoOldInt 

@@UArr:
        cmp AL, 48h                     ; Up arrow key
        jne @@DArr

        sub CS:CURDI, 80d * 12
        jmp @@NoOldInt

@@DArr:
        cmp AL, 50h                     ; Up arrow key
        jne @@NoOldInt

        add CS:CURDI, 80d * 12

@@NoOldInt:
        KBRD_ACK
        EOI

        pop AX BX DI ES
        iret

@@Fin:
        pop AX BX DI ES
        db 0EAh                         ; longjmp to old 09h
Old09   dd 0

endp

RegVal  db 4 dup ('0'), '$'
HEX     db '0123456789ABCDEFghijklmnop'
BRD	db 0DAh, 0C4h, 0BFh, 0B3h, ' ', 0B3h, 0C0h, 0C4h, 0D9h	; std border 1 symbols
CURDI   dw (80 * 2 - 8) * 2
LASTKEY db 00h
ISOn    db 00h
LShDwn  db 00h

BackBuf db ?

DataEnd:
end _start
