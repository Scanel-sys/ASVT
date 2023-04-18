.def TMP = R20
.def REGIME = R19
.def var_y = R18

.MACRO SWP
	PUSH @0
	MOV @0, @1
	POP @1
.ENDM

.org 0x000
	JMP init_board
.org 0x002
    JMP EXT_INT0 ; ptr to int0 handler
.org 0x004
    JMP EXT_INT1 ; ptr to int1 handler

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

EXT_INT0:
    RETI

EXT_INT1: ; Обработчик прерывания int1 (Поменять местами y и -y)
	SBIS PIND, 2
	JMP main_int1
	RCALL 	EEWrite 	; вызываем процедуру записи.
	RETI
main_int1:
	SWP _, _
	RETI ; Возврат из обработчика прерываний и разрешение прерываний


EEWrite:	
    LDI 	R16,0		; Загружаем адрес нулевой ячейки
	LDI 	R17,0		; EEPROM 
	MOV 	R21, REGIME ; и хотим записать в нее REGIME

	SBIC EECR, EEWE		; Ждем готовности памяти к записи. Крутимся в цикле
	RJMP EEWrite 		; до тех пор пока не очистится флаг EEWE
 
	;CLI					; Затем запрещаем прерывания.
	OUT EEARL, R16 		; Загружаем адрес нужной ячейки
	OUT EEARH, R17  	; старший и младший байт адреса
	OUT EEDR, R21 		; и сами данные, которые нам нужно загрузить
 
	SBI EECR, EEMWE		; взводим предохранитель
	SBI EECR, EEWE		; записываем байт
 
	;SEI 				; разрешаем прерывания
	RET 				; возврат из процедуры

EERead:	
	SBIC EECR, EEWE		; Ждем пока будет завершена прошлая запись.
	RJMP EERead			; также крутимся в цикле.
	
	OUT EEARL, R16		; загружаем адрес нужной ячейки
	OUT EEARH, R17 		; его старшие и младшие байты
	SBI EECR, EERE 		; Выставляем бит чтения
	IN R21, EEDR 		; Забираем из регистра данных результат
	RET

init_board:
	;setting I/O ports
	ldi TMP, 0x73       ; 01110011
	OUT DDRD, TMP
	
    SER TMP		        ; 0xFF
	OUT DDRA, TMP
	OUT DDRB, TMP
	OUT DDRC, TMP

    OUT PORTA, TMP
	OUT PORTB, TMP
	OUT PORTC, TMP

    ldi REGIME, 0x00
    ldi var_y, 0x55

	;setting stack hight to the end of RAM
	LDI TMP, HIGH(RAMEND)	; higher rank addr
	OUT SPH, TMP
	LDI TMP, LOW(RAMEND)
	OUT SPL, TMP

    LDI TMP, 0x0F
    OUT MCUCR, TMP ; Настройка прерываний int0 и int1 на условие 0/1
    LDI TMP, 0xC0
    OUT GICR, TMP ; Разрешение прерываний int0 и int1
    OUT GIFR, TMP ; Предотвращение срабатывания int0 и int1 при
    включении прерываний
    SEI ; Включение прерываний

main:
