.def TMP_1 = R26
.def TMP_2 = R25
.def TMP_3 = R24
.def excess_ticks = R23
.def DATA_1 = R22
.def DATA_2 = R21
.def TMP = R20
.def REGIME = R19
.def var_y = R18
.def var_y_additional = R17
.def var_x = R16
.dev var_i = R11
.def DELAY_LEN = R10
.def THIRD_REGIME = R9
.def SECOND_REGIME = R8
.def FIRST_REGIME = R7
.def REG_3_a = R6
.def REG_3_b = R5
.def REG_2_a = R4
.def REG_2_b = R3
.def REG_1_a = R2
.def REG_1_b = R1
.def REGIME_CEIL = R0

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
	ldi TMP, 0x10 		; 00010000
	mov TMP_3, REGIME	; TMP_3 is temp REGIME
	add TMP_3, TMP
	andi TMP_3, 0x30	; REGIME & 00110000
	cp TMP_3, REGIME_CEIL
	brne IF_FIRST_REGIME
	clr TMP_3
IF_FIRST_REGIME:
	cp TMP_3, FIRST_REGIME
	brne IF_SECOND_REGIME
	mov TMP_1, REG_1_a
	mov TMP_2, REG_1_b
	breq regime_end
IF_SECOND_REGIME:
	cp TMP_3, SECOND_REGIME
	brne IF_THIRD_REGIME
	mov TMP_1, REG_2_a
	mov TMP_2, REG_2_b
	breq regime_end
IF_THIRD_REGIME:
	mov TMP_1, REG_3_a
	mov TMP_2, REG_3_b
regime_end:
	in TMP, PORTD
	andi TMP, 0xCF		; TMP & 11001111
	or TMP, TMP_3		; TMP | REGIME
if_write_x_in_int0_loop:
	sbic PIND, 3
	jmp write_x_to_mem
	sbic PIND, 2
	jmp if_write_x_in_int0_loop
regime_case
	mov DATA_1, TMP_1
	mov DATA_2, TMP_2
	out PORTD, TMP
	mov REGIME, TMP_3
	RETI

EXT_INT1:		 		; changin SPEED / PD3
	mov TMP, var_x
	inc TMP
	cpi TMP, 0x3
	brne IF_FIRST_SPEED
	clr TMP
IF_FIRST_SPEED:
	cp TMP, 0
	brne IF_SECOND_SPEED
	ldi TMP_2, 10
	ldi TMP_3, 14
	breq speed_end
IF_SECOND_SPEED:
	cp TMP, 1
	brne IF_THIRD_SPEED
	ldi TMP_2, 20
	ldi TMP_3, 28
	breq speed_end
IF_THIRD_SPEED:
	ldi TMP_2, 40
	ldi TMP_3, 54
speed_end:
	in TMP_1, PORTD
	andi TMP_1, 0b11111100
	or TMP_1, TMP		; TMP_1 | var_x
if_write_x_in_int1_loop:
	sbic PIND, 2
	jmp write_x_to_mem
	sbic PIND, 3
	jmp if_write_x_in_int1_loop
speed_case:
	mov var_x, TMP
	mov DELAY_LEN, TMP_2
	mov excess_ticks, TMP_3
	out PORTD, TMP_1
	RETI
write_x_to_mem:
	call EEWrite
	ret
read_y:
	in TMP_1, PORTA
	in TMP_2, PORTB
	clr TMP
	out PORTA, TMP
	out PORTB, TMP
	out PORTC, TMP
	clr TMP_3
reading_y_loop:
	or TMP_3, PORTC
	out PORTA, TMP_3	; print out chosen bits
	sbic PIND, 7
	jmp reading_y_loop
	mov var_y, TMP_3
add_code_convert:
	ldi var_y_additional, 0xFF
	eor var_y_additional, var_y
	out  PORTA, TMP_1
	out  PORTB, TMP_2
	ret
EEWrite:
	push TMP_1
	push TMP_2
	push TMP	
    LDI 	TMP_1, 0x0	; Загружаем адрес нулевой ячейки
	LDI 	TMP_2, 0x0	; EEPROM 
	MOV 	TMP, var_x ; и хотим записать в нее REGIME

	SBIC EECR, EEWE		; Ждем готовности памяти к записи. Крутимся в цикле
	RJMP EEWrite 		; до тех пор пока не очистится флаг EEWE
 
	; CLI					; Затем запрещаем прерывания.
	OUT EEARL, TMP_1 		; Загружаем адрес нужной ячейки
	OUT EEARH, TMP_2	; старший и младший байт адреса
	OUT EEDR, TMP 		; и сами данные, которые нам нужно загрузить
 
	SBI EECR, EEMWE		; взводим предохранитель
	SBI EECR, EEWE		; записываем байт
 
	; SEI 				; разрешаем прерывания
	pop TMP
	pop TMP_2
	pop TMP_1
	RET 				; возврат из процедуры

EERead:
	; CLI					; Затем запрещаем прерывания.
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
	; SEI 				; разрешаем прерывания
	
	RET
init_x:
	call EERead
	cpi var_x, 4
	brlt init_x_end
	clr var_x
init_x_end:
	ret

init_board:
	;setting I/O ports
	ldi TMP, 0x73       ; 01110011
	OUT DDRD, TMP
	OUT PORTD, TMP
	
    SER TMP		        ; 0xFF
	OUT DDRA, TMP
	OUT DDRB, TMP
	OUT DDRC, TMP

    OUT PORTA, TMP
	OUT PORTB, TMP
	OUT PORTC, TMP

    ldi REGIME, 0x00
	ldi FIRST_REGIME, 0x00
	ldi SECOND_REGIME, 0x10
	ldi THIRD_REGIME, 0x20
    ldi var_y, 0x55
	call init_x
	ldi REGIME_CEIL, 0x30
	ldi REG_1_a, 0xFF
	ldi REG_1_b, 0x00
	ldi REG_2_a, 0xAA
	ldi REG_2_b, 0x55
	ldi REG_3_a, 0x55
	ldi REG_3_b, 0xAA
	ldi excess_ticks, 14

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
main:
	OUT PORTA, DATA_1
	OUT PORTB, DATA_1
	SWAP DATA_1, DATA_2
	clr var_i
delay_loop:
	call delay
	sbic PIND, 7
	call read_y
	inc var_i
	cp var_i, DELAY_LEN
	brlt delay_loop
	JMP main
