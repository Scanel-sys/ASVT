;= Start 	macro.inc ========================================
.def b0 = R24
.def b1 = R23
.def b2 = R22
.def outValue = R21
.def Position = R20
.def mlsecs = R19
.def paramNumber = R18
.def TMP_INTR = R17
.def TMP = R16
.def outp_4 = R9
.def outp_3 = R8
.def outp_2 = R7
.def outp_1 = R6
.def basic_shift = R5   ; d
.def step = R4          ; h
.def frequency = R3     ; p
.def ONE = R2
.def O = R1
.def Storage = R0
;= End 		macro.inc ========================================

; INTERRUPT TABLE ============================================
.org 0x000					 ; (RESET) 
	JMP init_board
.org 0x002
	JMP EXT_INT0             ; (INT0) Regime changer    / PD2
.org 0x004
    JMP EXT_INT1			 ; (INT1) Parameter chooser / PD3
.org 0x008
	JMP TIMER2COMP_INT		 ; 0,1 sec timer
; Interrupts =================================================
EXT_INT0:

    reti

EXT_INT1:
    mov mlsecs, O
    inc paramNumber
    cpi paramNumber, 6
    brlt prepare_parameter_info
    ldi paramNumber, 0
prepare_parameter_info:
    cpi paramNumber, 0
    breq b0_param
    cpi paramNumber, 1
    breq b1_param
    cpi paramNumber, 2
    breq b2_param
    cpi paramNumber, 3
    breq h_param
    cpi paramNumber, 4
    breq p_param
    cpi paramNumber, 5
    breq d_param 
b0_param:
    call place_b
    mov outp_1, outValue
    call place_zero
    call add_dot
    mov outp_2, outValue
    
    mov outValue, b0
    call convert_b_and_put_to_outpVars
    
    jmp EXT_INT1_EXIT
b1_param:
    call place_b
    mov outp_1, outValue
    call place_one
    call add_dot
    mov outp_2, outValue

    mov outValue, b1
    call convert_b_and_put_to_outpVars

    jmp EXT_INT1_EXIT
b2_param:
    call place_b
    mov outp_1, outValue
    call place_two
    call add_dot
    mov outp_2, outValue

    mov outValue, b2
    call convert_b_and_put_to_outpVars

    jmp EXT_INT1_EXIT
h_param:
    call place_h
    call add_dot
    mov outp_1, outValue   
    
    mov outp_2, O
    mov outp_3, O

    mov outValue, step
    call convert_for_7seg
    mov outp_4, outValue
    jmp EXT_INT1_EXIT
p_param:
    call place_p
    call add_dot
    mov outp_1, outValue
    
    mov outp_2, O
    mov outp_3, O
    
    mov outValue, frequency
    call convert_for_7seg
    mov outp_4, outValue
    jmp EXT_INT1_EXIT
d_param:
    call place_d
    call add_dot
    mov outp_1, outValue    

    mov outp_2, O
    mov outp_3, O
    
    mov outValue, basic_shift
    call convert_for_7seg
    mov outp_4, outValue
EXT_INT1_EXIT:
    reti

TIMER2COMP_INT:
	in Storage, SREG

	lsl Position
	sbrc Position, 4
	ldi Position, 0b00000001

	sbrc Position, 3
	out PORTC, outp_1
	sbrc Position, 2
	out PORTC, outp_2
	sbrc Position, 1
	out PORTC, outp_3
	sbrc Position, 0
	out PORTC, outp_4

	out SREG, Storage
	reti

; END Interrupts =============================================

; Board Init =================================================
init_board:

    ; init PORTS
    CLR TMP
    moc O, TMP
    ldi TMP, 0xDF
    out DDRA, TMP
    out DDRB, O
    out DDRC, O

    out PORTA, O
    out PORTB, O
    out PORTC, O

    ; init vars
    mov Position, O
    mov b1, O
    mov b2, O
    mov basic_shift, O
    mov paramNumber, O
    
    LDI TMP, 1
    mov ONE, TMP
    mov b0, ONE
    mov step, ONE

    LDI TMP, 3
    mov frequency, TMP

    ; init 0,01 sec timer
	LDI TMP, 0b00001101
	OUT TCCR2, TMP
	LDI TMP, 0b11111111
	OUT OCR2, TMP
	call turn_on_small_timer

    ; INTERRUPTS init
    LDI TMP, 0x0F
    OUT MCUCR, TMP      ; Настройка прерываний int0 и int1 на условие 0/1
    LDI TMP, 0b11000000
    OUT GICR, TMP       ; Разрешение прерываний int0 и int1
    OUT GIFR, TMP       ; Предотвращение срабатывания int0 и int1 при
    			        ; включении прерываний
    
    SEI
; End Board Init =============================================

; Main =======================================================
main:


; Procedures =================================================
turn_off_small_timer:
	in TMP_2, TIMSK
	ANDI TMP_2, 0b01111111
	OUT TIMSK, TMP_2
	ret
turn_on_small_timer:
	in TMP_2, TIMSK
	ORI TMP_2, 0b10000000
	out TIMSK, TMP_2
	ret


convert_b_and_put_to_outpVars:
    cpi outValue, 0x10
    brlt get_second_val_from_b
    breq b_val_10
    cpi outValue, 0x20
    breq b_val_20
    cpi outValue, 0x40
    breq b_val_40
b_val_10:
    call place_one
    mov outp_3, outValue
    jmp first_b_val_exit
b_val_20:
    call place_two
    mov outp_3, outValue
    jmp first_b_val_exit
b_val_40:
    call place_four
    mov outp_3, outValue
first_b_val_exit:
    call place_zero
    mov outp_4, outValue
    ret
get_second_val_from_b:
    mov outp_3, O
    call convert_for_7seg
    mov outp_4, outValue
    ret


convert_for_7seg:
	CPI outValue, 0
	BREQ place_zero
	CPI outValue, 1
	BREQ place_one
	CPI outValue, 2
	BREQ place_two
	CPI outValue, 3
	BREQ place_three
	CPI outValue, 4
	BREQ place_four
	CPI outValue, 5
	BREQ place_five
	CPI outValue, 6
	BREQ place_six
	CPI outValue, 7
	BREQ place_seven
	CPI outValue, 8
	BREQ place_eight
	CPI outValue, 9
	BREQ place_nine
	breq place_notset
place_zero:	    LDI outValue, 0b00111111
	ret
place_one:	    LDI outValue, 0b00000110
	ret
place_two:	    LDI outValue, 0b01011011
	ret
place_three:	LDI outValue, 0b01001111
	ret
place_four:	    LDI outValue, 0b01100110
	ret
place_five:	    LDI outValue, 0b01101101
	ret
place_six:	    LDI outValue, 0b01111101
	ret
place_seven:	LDI outValue, 0b00000111
	ret
place_eight:	LDI outValue, 0b01111111
	ret
place_nine:	    LDI outValue, 0b01101111
	ret
place_a:        LDI outValue, 0b01110111
    ret
place_b:        LDI outValue, 0b01111100
    ret
place_c:        LDI outValue, 0b00111001
    ret
place_d:        LDI outValue, 0b00111110
    ret
place_e:        LDI outValue, 0b01111001
    ret
place_f:        LDI outValue, 0b01110001
    ret
place_h:        LDI outValue, 0b01110100
    ret
place_p:        LDI outValue, 0b01110011
    ret
add_dot:        ORI outValue, 0b10000000
    ret
place_notset:	LDI outValue, 0b00001000
	ret

