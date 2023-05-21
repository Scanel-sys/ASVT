.def outValue = R23
.def REGIME = R19
.def TMP_2 = R18
.def TMP_1 = R17
.def TMP = R16
.def O = R9
.def code4 = R8
.def code3 = R7
.def code2 = R6
.def code1 = R5
.def DIS4 = R4
.def DIS3 = R3
.def DIS2 = R2
.def DIS1 = R1
.def TRIES = R0

;= Start 	macro.inc ========================================
.MACRO PUSHF
	PUSH TMP
	IN TMP, SREG
	PUSH TMP
.ENDM
.MACRO POPF
	POP TMP
	OUT SREG, TMP
	POP TMP
.ENDM
;= End 		macro.inc ========================================

; FLASH ======================================================
	.CSEG ; Кодовый сегмент

.org 0x000
	JMP init_board
.org 0x004
    JMP EXT_INT1
.ORG $00E
	JMP TIMER1COMPA_INT      ; (TIMER1 COMPA) Timer/Counter1 Compare Match A
.ORG $008
	JMP TIMER2COMP_INT		 ; (TIMER2 COMP) Timer/Counter2 Compare Match
; Interrupts =================================================

EXT_INT1:
    reti

TIMER1COMPA_INT:
	reti

TIMER2COMP_INT
	reti

; End Interrupts =============================================

EERead_code:
    LDI 	TMP_1, 0x0	; Загружаем адрес нулевой ячейки
	LDI 	TMP_2, 0x0	; EEPROM 
EERead_loop:
	SBIC EECR, EEWE		; Ждем пока будет завершена прошлая запись.
	RJMP EERead_loop1			; также крутимся в цикле.
	
	OUT EEARL, TMP_1		; загружаем адрес нужной ячейки
	OUT EEARH, TMP_2 		; его старшие и младшие байты
	SBI EECR, EERE 		; Выставляем бит чтения
	IN TMP, EEDR 		; Забираем из регистра данных результат
	
	cpi TMP_1, 0
	breq first_ciph
	cpi TMP_1, 1
	breq sec_ciph
	cpi TMP_1, 2
	breq third_ciph
	cpi TMP_1, 3
	breq fourth_ciph
first_ciph:
	mov code1, TMP
	breq EEprom_loop_end
sec_ciph;
	mov code2, TMP
	breq EEprom_loop_end
third_ciph:
	mov code3, TMP
	breq EEprom_loop_end
fourth_ciph:
	mov code4, TMP
EEprom_loop_end:
    inc TMP_1
	cpi TMP_1, 4
	brlt EERead_loop
	ret

; Internal Hardware Init ======================================
init_board:
    ldi TMP, 0b11000000
    out DDRA, TMP

	clr TMP
    out DDRB, TMP
	out DDRD, TMP
	
    OUT PORTA, TMP
	OUT PORTB, TMP
	OUT PORTC, TMP
	OUT PORTD, TMP
    
	mov TRIES, TMP
    mov DIS1, TMP
    mov DIS2, TMP
    mov DIS3, TMP
    mov DIS4, TMP
    mov REGIME, TMP
    
    ser TMP
    out DDRC, TMP
    out PORTC, TMP

	clr O
	;setting stack hight to the end of RAM
	LDI TMP, HIGH(RAMEND)	; higher rank addr
	OUT SPH, TMP
	LDI TMP, LOW(RAMEND)
	OUT SPL, TMP

    LDI TMP, 0b00001100
    OUT MCUCR, TMP ; Настройка прерываний int1 на условие 0/1
    LDI TMP, 0b10000000
    OUT GICR, TMP ; Разрешение прерываний int1
    OUT GIFR, TMP ; Предотвращение срабатывания int1 при
    			  ; включении прерываний
    call EERead_code

    mov TMP, code4

    SEI ; Включение прерываний

; End Internal Hardware Init ===================================

; Main =========================================================
main:
	in TMP_1, PINB
	in TMP_2, PINA
	andi TMP_2, 0b00110000
	tst TMP_1
	breq pinB_zero 
pinB_not_zero:
	cpse TMP_2, O
	jmp bad_input
	call convert_PINB
	jmp bad_input
pinB_zero:
	cpse TMP_2, O
	call convert_PINA
bad_input:
    jmp main

inf_loop:
	jmp inf_loop

; Procedure ====================================================

convert_PINB:
	cpi TMP_1, 1
	BREQ zero
	cpi TMP_1, 2
	BREQ one
	cpi TMP_1, 4
	BREQ two
	cpi TMP_1, 8
	BREQ three
	cpi TMP_1, 16
	BREQ four
	cpi TMP_1, 32
	BREQ five
	cpi TMP_1, 64
	BREQ six
	cpi TMP_1, 128
	BREQ seven
	ret
convert_PINA:
	cpi TMP_2, 0b00010000		; check if == 8	
	brne if_PA5
	call eight
	ret
if_PA5:
	call nine					; check if == 9
	ret
zero:	
	LDI outValue, 0b00111111
zero_loop:
	sbic PINB, 0
	jmp zero_loop
	RET
one:	
	LDI outValue, 0b00000110
one_loop:
	sbic PINB, 1
	jmp one_loop
	RET
two:	
	LDI outValue, 0b01011011
two_loop:
	sbic PINB, 2
	jmp two_loop
	RET
three:	
	LDI outValue, 0b01001111
three_loop:
	sbic PINB, 3
	jmp three_loop
	RET
four:	
	LDI outValue, 0b01100110
four_loop:
	sbic PINB, 4
	jmp four_loop
	RET
five:	
	LDI outValue, 0b01101101
five_loop:
	sbic PINB, 5
	jmp five_loop
	RET
six:	
	LDI outValue, 0b01111101
six_loop:
	sbic PINB, 6
	jmp six_loop
	RET
seven:	
	LDI outValue, 0b00000111
seven_loop:
	sbic PINB, 7
	jmp seven_loop
	RET
eight:	
	LDI outValue, 0b01111111
eight_loop:
	sbic PINA, 4
	jmp eight_loop
	RET
nine:	
	LDI outValue, 0b01101111
nine_loop:
	sbic PINA, 5
	jmp nine_loop
	RET

