.def TMP_1 = R25
.def TMP_2 = R24
.def TMP_3 = R23
.def TMP = R22
.def excess_ticks = R21
.def status_bit = R20
.def if_written = R19
.def REGIME = R18
.def var_y = R17
.def var_y_additional = R16
.def var_x = R15
.def DATA_1 = R13
.def DATA_2 = R12
.def var_i = R11
.def DELAY_LEN = R10

.MACRO SWP
	PUSH @0
	MOV @0, @1
	POP @1
.ENDM
;= End macro.inc ==================================

; FLASH ===========================================
	.CSEG ; Кодовый сегмент

.org 0x000
	JMP init_board
.org 0x002
    JMP EXT_INT0 ; ptr to int0 handler
.org 0x004
    JMP EXT_INT1 ; ptr to int1 handler
;----------------------------------------------------------------------

delay: 
	LDI R29, 0b00110110		; 57142 == R30:R29
	LDI R30, 0b11011111
	SUB R29, excess_ticks
delay_sub:
	SUBI R29, 1
	SBCI R30, 0
	nop
	nop
	nop
	brcc delay_sub
	RET

EXT_INT0:				; changin REGIME / PD2
	mov TMP_3, REGIME	; TMP_3 is temp REGIME
	cpi TMP_3, 0b00110000
	brne REGIME_NOT_CEIL
	clr TMP_3
REGIME_NOT_CEIL:
	ldi TMP,    0b00010000 ; 		   00010000
	add TMP_3, TMP
	andi TMP_3, 0b00110000	; REGIME & 00110000
IF_FIRST_REGIME:
	cpi TMP_3,  0b00010000
	brne IF_SECOND_REGIME
	ldi TMP_1, 0xFF
	ldi TMP_2, 0x0
	breq regime_main
IF_SECOND_REGIME:
	cpi TMP_3,  0b00100000
	brne IF_THIRD_REGIME
	ldi TMP_1, 0xAA
	ldi TMP_2, 0x55
	breq regime_main
IF_THIRD_REGIME:
	mov TMP_1, var_y
	mov TMP_2, var_y_additional
regime_main:
	in TMP, PORTD
	andi TMP, 0b11001111
	or TMP, TMP_3		; PORTD | REGIME
if_write_x_in_int0_loop:
	sbic PIND, 3
	call EEWrite
	sbic PIND, 2
	jmp if_write_x_in_int0_loop
	cpi if_written, 1
	breq regime_end
regime_case:
	mov DATA_1, TMP_1
	mov DATA_2, TMP_2
	out PORTD, TMP
	mov REGIME, TMP_3
regime_end:
	clr if_written
	RETI

EXT_INT1:		 		; changin SPEED / PD3
	mov TMP, var_x
	inc TMP
	cpi TMP, 0x3
	brlt IF_FIRST_SPEED
	clr TMP
IF_FIRST_SPEED:
	cpi TMP, 0
	brne IF_SECOND_SPEED
	ldi TMP_2, 40
	ldi TMP_3, 54
	breq speed_main
IF_SECOND_SPEED:
	cpi TMP, 1
	brne IF_THIRD_SPEED
	ldi TMP_2, 20
	ldi TMP_3, 28
	breq speed_main
IF_THIRD_SPEED:
	ldi TMP_2, 10
	ldi TMP_3, 14
speed_main:
	in TMP_1, PORTD
	andi TMP_1, 0b11111100
	or TMP_1, TMP		; TMP_1 | var_x
if_write_x_in_int1_loop:
	sbic PIND, 2
	call EEWrite
	sbic PIND, 3
	jmp if_write_x_in_int1_loop
	cpi if_written, 1
	breq speed_end
speed_case:
	mov var_x, TMP
	mov DELAY_LEN, TMP_2
	mov excess_ticks, TMP_3
	out PORTD, TMP_1
speed_end:
	clr if_written
	RETI
read_y:
	in TMP_1, PORTA
	in TMP_2, PORTB
	clr TMP
	out PORTA, TMP
	out PORTB, TMP
	out PORTC, TMP
	out DDRC, TMP
	clr TMP_3
reading_y_loop:
	in TMP, PINC
	or TMP_3, TMP
	out PORTA, TMP_3	; print out chosen bits
	sbic PIND, 7
	jmp reading_y_loop
	mov var_y, TMP_3
add_code_convert:
	ser TMP
	mov var_y_additional, TMP
	eor var_y_additional, var_y
	cpi REGIME, 0b00110000
	brlt if_not_third_regime
	mov TMP_1, var_y
	mov TMP_2, var_y_additional
	mov DATA_1, var_y
	mov DATA_2, var_y_additional
if_not_third_regime:
	out  PORTA, TMP_1
	out  PORTB, TMP_2
	out  PORTC, TMP
	out  DDRC, TMP
	ret
EEWrite:
	push TMP_1
	push TMP_2
	push TMP	
    LDI 	TMP_1, 0x0	; Загружаем адрес нулевой ячейки
	LDI 	TMP_2, 0x0	; EEPROM 
	MOV 	TMP, var_x ; и хотим записать в нее speed (var_x)

	SBIC EECR, EEWE		; Ждем готовности памяти к записи. Крутимся в цикле
	RJMP EEWrite 		; до тех пор пока не очистится флаг EEWE
 
	CLI					; Затем запрещаем прерывания.
	OUT EEARL, TMP_1 		; Загружаем адрес нужной ячейки
	OUT EEARH, TMP_2	; старший и младший байт адреса
	OUT EEDR, TMP 		; и сами данные, которые нам нужно загрузить
 
	SBI EECR, EEMWE		; взводим предохранитель
	SBI EECR, EEWE		; записываем байт
	
	ldi if_written, 1
	SEI 				; разрешаем прерывания
	pop TMP
	pop TMP_2
	pop TMP_1
	RET 				; возврат из процедуры

EERead:
	CLI					; Затем запрещаем прерывания.
	push TMP_1
	push TMP_2
    LDI 	TMP_1, 0x0	; Загружаем адрес нулевой ячейки
	LDI 	TMP_2, 0x0	; EEPROM 

	SBIC EECR, EEWE		; Ждем пока будет завершена прошлая запись.
	RJMP EERead			; также крутимся в цикле.
	
	OUT EEARL, TMP_1		; загружаем адрес нужной ячейки
	OUT EEARH, TMP_2 		; его старшие и младшие байты
	SBI EECR, EERE 		; Выставляем бит чтения
	IN var_x, EEDR 		; Забираем из регистра данных результат
	
	pop TMP_2
	pop TMP_1
	SEI 				; разрешаем прерывания
	
	RET
init_x:
	call EERead
	ldi TMP, 4
	cp var_x, TMP
	brlt init_x_end
	clr var_x
init_x_end:
	mov TMP, var_x
	call IF_FIRST_SPEED
	ret

init_board:
	;setting I/O ports
	ldi TMP, 0b01110011
	OUT DDRD, TMP
	ldi TMP, 0b00010000
	OUT PORTD, TMP
	
	ser TMP
	mov DATA_1, TMP
	clr TMP
	mov DATA_2, TMP

    SER TMP		        ; 0xFF
	OUT DDRA, TMP
	OUT DDRB, TMP
	OUT DDRC, TMP

    OUT PORTA, TMP
	OUT PORTB, TMP
	OUT PORTC, TMP

    ldi REGIME, 0b00010000
    ldi var_y, 0b01010101
    ldi var_y_additional, 0b10101010

	clr TMP
	; mov var_x, TMP
	ldi status_bit, 0b01000000
	ldi excess_ticks, 14
	ldi if_written, 0

	;setting stack hight to the end of RAM
	LDI TMP, HIGH(RAMEND)	; higher rank addr
	OUT SPH, TMP
	LDI TMP, LOW(RAMEND)
	OUT SPL, TMP

    LDI TMP, 0x0F
    OUT MCUCR, TMP ; Настройка прерываний int0 и int1 на условие 0/1
    LDI TMP, 0b11000000
    OUT GICR, TMP ; Разрешение прерываний int0 и int1
    OUT GIFR, TMP ; Предотвращение срабатывания int0 и int1 при
    			  ; включении прерываний
    SEI ; Включение прерываний
	call init_x

main:
	in TMP, PORTD
	EOR TMP, status_bit
	OUT PORTA, DATA_1
	OUT PORTB, DATA_2
	OUT PORTD, TMP
	SWP DATA_1, DATA_2
	clr var_i
delay_loop:
	call delay
	sbic PIND, 7
	call read_y
	inc var_i
	cp var_i, DELAY_LEN
	brlt delay_loop
	JMP main
