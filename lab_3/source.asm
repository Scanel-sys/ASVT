;= Start 	macro.inc ========================================
.def Position = R24
.def outValue = R23
.def WRONG_PIN_SECONDS = R21
.def SECONDS = R20
.def REGIME = R19
.def TMP_2 = R18
.def TMP_1 = R17
.def TMP = R16
.def IF_COUNTED = R12
.def TRIES = R11
.def ONE = R10
.def O = R9
.def code4 = R8
.def code3 = R7
.def code2 = R6
.def code1 = R5
.def inp_4 = R4
.def inp_3 = R3
.def inp_2 = R2
.def inp_1 = R1
.def Storage = R0
;= End 		macro.inc ========================================

; FLASH ======================================================
	.CSEG ; Кодовый сегмент

; INTERRUPT TABLE ============================================
.org 0x000					 ; (RESET) 
	JMP init_board
.org 0x004
    JMP EXT_INT1			 ; (INT1) External Interrupt Request 1
.ORG 0x008
	JMP TIMER2COMP_INT		 ; (TIMER2 COMP)  Timer/Counter2 Compare Match | 7seg work
.ORG 0x00E
	JMP TIMER1COMPA_INT      ; (TIMER1 COMPA) Timer/Counter1 Compare Match A
; Interrupts =================================================

EXT_INT1:
	call reset_input
	clr TRIES
	LDI REGIME, 1
	clr IF_COUNTED
    reti

TIMER1COMPA_INT:
	in Storage, SREG
if_sec_regime:
	cpi REGIME, 2
	brne if_first_regime
	inc WRONG_PIN_SECONDS
	cpi WRONG_PIN_SECONDS, 20
	brlt one_sec_timer_end
	mov IF_COUNTED, ONE
	clr WRONG_PIN_SECONDS
	jmp one_sec_timer_end
if_first_regime:
	inc SECONDS
	cpi SECONDS, 7
	brlt one_sec_timer_end
	clr SECONDS
	call reset_input
one_sec_timer_end:
	out SREG, Storage
	reti

TIMER2COMP_INT:
	in Storage, SREG

	lsl Position
	sbrc Position, 4
	ldi Position, 0b00000001
	out PORTA, Position

	sbrc Position, 3
	out PORTC, inp_1
	sbrc Position, 2
	out PORTC, inp_2
	sbrc Position, 1
	out PORTC, inp_3
	sbrc Position, 0
	out PORTC, inp_4

	out SREG, Storage
	reti
; End Interrupts =============================================

EERead_code:
	in Storage, SREG
    LDI 	TMP_1, 0x0	; Загружаем адрес нулевой ячейки
	LDI 	TMP_2, 0x0	; EEPROM 
EERead_loop:
	SBIC EECR, EEWE		; Ждем пока будет завершена прошлая запись.
	RJMP EERead_loop			; также крутимся в цикле.
	
	OUT EEARL, TMP_1		; загружаем адрес нужной ячейки
	OUT EEARH, TMP_2 		; его старшие и младшие байты
	SBI EECR, EERE 		; Выставляем бит чтения
	IN TMP, EEDR 		; Забираем из регистра данных результат
	
	cpi TMP, 10
	brge EEprom_bad_input
	cpi TMP, 0
	brlt EEprom_bad_input

	mov outValue, TMP
	call Conv

	cpi TMP_1, 0
	breq first_ciph
	cpi TMP_1, 1
	breq sec_ciph
	cpi TMP_1, 2
	breq third_ciph
	cpi TMP_1, 3
	breq fourth_ciph
first_ciph:
	mov code1, outValue
	breq EEprom_loop_end
sec_ciph:
	mov code2, outValue
	breq EEprom_loop_end
third_ciph:
	mov code3, outValue
	breq EEprom_loop_end
fourth_ciph:
	mov code4, outValue
EEprom_loop_end:
    inc TMP_1
	cpi TMP_1, 4
	brlt EERead_loop
EEprom_end:
	out SREG, Storage
	ret
EEprom_bad_input:
	call eeprom_bad_input_output
	mov inp_1, outValue
	mov inp_2, outValue
	mov inp_3, outValue
	mov inp_4, outValue
	SEI
	jmp inf_loop

; Internal Hardware Init =======================================
init_board:

	;setting stack hight to the end of RAM
	LDI TMP, HIGH(RAMEND)	; higher rank addr
	OUT SPH, TMP
	LDI TMP, LOW(RAMEND)
	OUT SPL, TMP

	clr O
	ldi TMP, 1
	mov ONE, TMP

	; ports init
    ldi TMP, 0b11001111
    out DDRA, TMP
    out DDRB, O
    ser TMP
    out DDRC, TMP
	ldi TMP, 0b11110111
	out DDRD, TMP

    OUT PORTA, O
	OUT PORTB, O
	OUT PORTC, O
	OUT PORTD, O
    
	; init user interact info
	clr TRIES
	call notset
	mov inp_1, outValue
	mov inp_2, outValue
	mov inp_3, outValue
	mov inp_4, outValue
    clr REGIME
	ldi Position, 0b00000001
	clr IF_COUNTED

	; Инициализация таймера на 0,01 секунду
	LDI TMP, 0b00001101
	OUT TCCR2, TMP
	LDI TMP, 0b11111111
	OUT OCR2, TMP
	call turn_on_small_timer

	; Инициализация таймера на 1 секунду
	LDI TMP, 0b00001100
	OUT TCCR1B, TMP
	LDI TMP, 0b01111010
	OUT OCR1AH, TMP
	LDI TMP, 0b00010010
	OUT OCR1AL, TMP

	; read code, if wrong format -> goto inf_loop
    ; call EERead_code
	ldi outValue, 3
	call Conv
	mov code1, outValue

	ldi outValue, 3
	call Conv
	mov code2, outValue

	ldi outValue, 0
	call Conv
	mov code3, outValue

	ldi outValue, 1
	call Conv
	mov code4, outValue
	
	;int1
    LDI TMP, 0b00001100
    OUT MCUCR, TMP ; Настройка прерываний int1 на условие 0/1
	
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
	tst TMP_2
	brne main
	call convert_PINB
	jmp check_input
pinB_zero:
	tst TMP_2
	breq main
	call convert_PINA
check_input:
	clr SECONDS
	inc TMP
	cpi TMP, 1
	breq check_1_inp
	cpi TMP, 2
	breq check_2_inp
	cpi TMP, 3
	breq check_3_inp
	cpi TMP, 4
	breq check_4_inp
	jmp wrong_input
check_1_inp:
	call turn_on_big_timer
	mov REGIME, ONE
	mov inp_1, outValue
	cpse outValue, code1
	jmp wrong_input
	jmp main
check_2_inp:
	mov inp_2, outValue
	cpse outValue, code2
	jmp wrong_input
	jmp main
check_3_inp:
	mov inp_3, outValue
	cpse outValue, code3
	jmp wrong_input
	jmp main
check_4_inp:
	mov inp_4, outValue
	cpse outValue, code4
	jmp wrong_input
correct_input:
	call turn_off_big_timer
	LDI TMP_2, 0b10000000
	OUT PORTA, TMP_2
	call turn_on_int1
	clr REGIME
	jmp inf_loop
wrong_input:
	LDI REGIME, 2
	CLR WRONG_PIN_SECONDS
	inc TRIES
	LDI TMP_2, 0b01000000
	OUT PORTA, TMP_2
	ldi TMP_1, 3
	cp TRIES, TMP_1
	brge wrong_user
wrong_input_loop:
	cpse IF_COUNTED, ONE
	jmp wrong_input_loop
	out PORTA, O
	mov IF_COUNTED, O
	call turn_off_big_timer
	LDI REGIME, 1
	call reset_input
	jmp main
wrong_user:
	call turn_off_big_timer
	clr REGIME
	ldi TMP, 0b11000000
	out PORTA, TMP
	call bad_user_out
	mov inp_1, outValue
	mov inp_2, outValue
	mov inp_3, outValue
	mov inp_4, outValue
inf_loop:
	cp REGIME, O
	breq inf_loop
	jmp main
; Procedure ====================================================
reset_input:
	clr TMP
	clr SECONDS
	call turn_off_int1
	call notset
	mov inp_1, outValue
	mov inp_2, outValue
	mov inp_3, outValue
	mov inp_4, outValue
	ret

turn_on_int1:
	push TMP
    LDI TMP, 0b10000000
    OUT GICR, TMP ; Разрешение прерываний int1
    OUT GIFR, TMP ; Предотвращение срабатывания int1 при
    			  ; включении прерываний
	pop TMP
	ret

turn_off_int1:
    OUT GICR, O
    OUT GIFR, O 
	ret

turn_off_big_timer:
	push TMP_2
	in TMP_2, TIMSK
	ANDI TMP_2, 0b11101111
	OUT TIMSK, TMP_2
	pop TMP_2
	ret
turn_on_big_timer:
	push TMP_2
	in TMP_2, TIMSK
	ORI TMP_2, 0b00010000
	out TIMSK, TMP_2
	pop TMP_2
	ret
turn_off_small_timer:
	push TMP_2
	in TMP_2, TIMSK
	ANDI TMP_2, 0b01111111
	OUT TIMSK, TMP_2
	pop TMP_2
	ret
turn_on_small_timer:
	push TMP_2
	in TMP_2, TIMSK
	ORI TMP_2, 0b10000000
	out TIMSK, TMP_2
	pop TMP_2
	ret

convert_PINB:
	cpi TMP_1, 1
	BREQ zero
	cpi TMP_1, 2
	BREQ one_inp
	cpi TMP_1, 4
	BREQ two_inp
	cpi TMP_1, 8
	BREQ three_inp
	cpi TMP_1, 16
	BREQ four_inp
	cpi TMP_1, 32
	BREQ five_inp
	cpi TMP_1, 64
	BREQ six_inp
	cpi TMP_1, 128
	BREQ seven_inp
	ldi TMP, -1
	ret
convert_PINA:
	cpi TMP_2, 0b00010000		; check if == 8	
	brne if_PA5_and_6
	call eight_inp
	ret
if_PA5_and_6:
	cpi TMP_2, 0b00100000
	breq if_PA5
	ldi TMP, -1
	ret
if_PA5:
	call nine_inp					; check if == 9
	ret

zero:	
	clr outValue
	call Conv
zero_loop:
	sbic PINB, 0
	jmp zero_loop
	RET

one_inp:	
	LDI outValue, 1
	call Conv
one_loop:
	sbic PINB, 1
	jmp one_loop
	RET

two_inp:	
	LDI outValue, 2
	call Conv
two_loop:
	sbic PINB, 2
	jmp two_loop
	RET

three_inp:	
	LDI outValue, 3
	call Conv
three_loop:
	sbic PINB, 3
	jmp three_loop
	RET

four_inp:	
	LDI outValue, 4
	call Conv
four_loop:
	sbic PINB, 4
	jmp four_loop
	RET

five_inp:	
	LDI outValue, 5
	call Conv
five_loop:
	sbic PINB, 5
	jmp five_loop
	RET

six_inp:	
	LDI outValue, 6
six_loop:
	sbic PINB, 6
	jmp six_loop
	RET

seven_inp:	
	LDI outValue, 7
seven_loop:
	sbic PINB, 7
	jmp seven_loop
	RET

eight_inp:	
	LDI outValue, 8
	call Conv
eight_loop:
	sbic PINA, 4
	jmp eight_loop
	RET

nine_inp:	
	LDI outValue, 9
	call Conv
nine_loop:
	sbic PINA, 5
	jmp nine_loop
	RET

Conv:
	CPI outValue, 0
	BREQ conv_zero
	CPI outValue, 1
	BREQ conv_one
	CPI outValue, 2
	BREQ conv_two
	CPI outValue, 3
	BREQ conv_three
	CPI outValue, 4
	BREQ conv_four
	CPI outValue, 5
	BREQ conv_five
	CPI outValue, 6
	BREQ conv_six
	CPI outValue, 7
	BREQ conv_seven
	CPI outValue, 8
	BREQ conv_eight
	CPI outValue, 9
	BREQ conv_nine
	JMP notset

conv_zero:	LDI outValue, 0b00111111
	RET
conv_one:	LDI outValue, 0b00000110
	RET
conv_two:	LDI outValue, 0b01011011
	RET
conv_three:	LDI outValue, 0b01001111
	RET
conv_four:	LDI outValue, 0b01100110
	RET
conv_five:	LDI outValue, 0b01101101
	RET
conv_six:	LDI outValue, 0b01111101
	RET
conv_seven:	LDI outValue, 0b00000111
	RET
conv_eight:	LDI outValue, 0b01111111
	RET
conv_nine:	LDI outValue, 0b01101111
	RET
notset:	LDI outValue, 0b00001000
	RET
eeprom_bad_input_output:	LDI outValue, 0b01001001
	RET
bad_user_out:	LDI outValue, 0b00110110
	RET
	