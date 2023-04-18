/*
 * lab_1.asm
 *
 *  Created: 08.04.2023 17:40:29
 *   Author: scanel
 */ 

.def TMP = R20

.org $000
	JMP reset

delay: ; 1282(255 - y) + 5x + 4nop = 79993
	LDI R29, 101	; x xnew = 101
	LDI R30, 193	; y ynew = 193
delay_sub:
	NOP
	DEC R29
	NOP
	BRNE delay_sub
	INC R30
	BRNE delay_sub
	NOP
	NOP
	NOP
	NOP
	RET

;default setting
reset:
	LDI TMP, 0x01
	MOV R0, TMP
	CLR TMP
	MOV R1, TMP
	MOV R2, TMP
	MOV R3, TMP
	;setting I/O ports
	SER TMP		; 0xFF
	OUT DDRA, TMP
	OUT DDRB, TMP
	OUT DDRC, TMP
	OUT DDRD, TMP
	;setting stack hight to the end of RAM
	LDI TMP, HIGH(RAMEND)	; higher rank addr
	OUT SPH, TMP
	LDI TMP, LOW(RAMEND)
	OUT SPL, TMP

;main cycle
loop:
	;cyclic shift 32-bit number R0-R3
	BST R0, 0	;saving lower bit to T
	LSR R3		;logic shift to right� 1 put in C
	ROR R2		;again ... C put to 7th R2 bit, 0s bit put to C
	ROR R1
	ROR R0		;again
	BLD R3, 7	;7th bit of R3 = T
	; showing 32-bit numb R0-R3 to PORTA-PORTD
	OUT PORTA, R0
	OUT PORTB, R1
	OUT PORTC, R2
	OUT PORTD, R3
	; PAUSE
	CALL delay
	RJMP loop
