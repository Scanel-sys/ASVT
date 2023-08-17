;= Start 	macro.inc ========================================

.def shift_counter = R22
.def outValue = R21
.def Position = R20
.def new_shift = R19
.def paramNumber = R18
.def blink_counter = R17
.def TMP = R16
.def step = R12
.def b0 = R11
.def b1 = R10
.def b2 = R9
.def REGIME = R8
.def outp_4 = R7
.def outp_3 = R6
.def outp_2 = R5
.def outp_1 = R4
.def basic_shift = R3   ; d
.def ONE = R2
.def O = R1
.def Storage = R0
;= End 		macro.inc ========================================

; INTERRUPT TABLE ============================================
.org 0x000					 
	JMP init_board               ; (RESET) 
.org 0x002
	JMP EXT_INT0                 ; (INT0) Regime changer    / PD2
.org 0x004
    JMP EXT_INT1			     ; (INT1) Parameter chooser / PD3
.org 0x008
	RETI            		     ; PD7
.org 0x00E
	RETI                         ; PD4
.org 0x014
	JMP SEG7_LIGHTS_TIMER_INT	 ; 0,01 sec timer + 0,1 sec timer
; Interrupts =================================================
EXT_INT0:
	in Storage, SREG
    eor REGIME, ONE
    clr blink_counter
    out SREG, Storage
    reti

EXT_INT1:
	in Storage, SREG

    cp REGIME, O
    breq EXT_INT1_EXIT

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
    jmp EXT_INT1_EXIT
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
    
    ldi outValue, 3
    call convert_for_7seg
    mov outp_4, outValue
    jmp EXT_INT1_EXIT
d_param:
    call place_d
    call add_dot
    mov outp_1, outValue    

    mov outp_2, O
    mov outp_3, O
EXT_INT1_EXIT:
    out SREG, Storage
    reti

SEG7_LIGHTS_TIMER_INT:
    in Storage, SREG
    
    cp REGIME, ONE
    breq SEG_7_SHOW

    inc blink_counter
    cpi blink_counter, 10           ; timer is ~0,01 so its too fast for garland 
    brlo SEG7_LIGHTS_END
    
    clr blink_counter
    push shift_counter
    clr shift_counter

    mov outp_1, b0
    mov outp_2, b1
    mov outp_3, b2
LIGHTS_MAKE_SHIFT:
    mov TMP, b0
    rol TMP
    rol b2
    rol b1
    rol b0

    or outp_1, b0
    or outp_2, b1
    or outp_3, b2
    out PORTA, outp_1
    out PORTB, outp_2
    out PORTC, outp_3

    inc shift_counter
    cp shift_counter, step            ; shift size; can be changed
    brlo LIGHTS_MAKE_SHIFT
    pop shift_counter

    out PORTA, b0
    out PORTB, b1
    out PORTC, b2

    jmp SEG7_LIGHTS_END
SEG_7_SHOW:
    inc blink_counter
	lsr Position

	sbrc Position, 3
	out PORTC, outp_1
	sbrc Position, 2
	out PORTC, outp_2

    cpi blink_counter, 50
	brge skip_second_part
display_sec_part:
    sbrc Position, 1
	out PORTC, outp_3
	sbrc Position, 0
	out PORTC, outp_4
    jmp TIMER2COMP_INT_EXIT
skip_second_part:
    cpi blink_counter, 100
    brlt TIMER2COMP_INT_EXIT
    clr blink_counter
TIMER2COMP_INT_EXIT:
	sbrc Position, 0
	ldi Position, 0b00010000
SEG7_LIGHTS_END:
    out SREG, Storage
    reti
; END Interrupts =============================================

; Board Init =================================================
init_board:
	; init stack
	LDI TMP, High(RAMEND)
	OUT SPH, TMP
	LDI TMP, Low(RAMEND)
	OUT SPL, TMP

    ; init ports
    clr O
    ldi TMP, 0xDF
    out DDRA, TMP
    out DDRB, O
    out DDRC, O

    out PORTA, O
    out PORTB, O
    out PORTC, O

    ; init vars
    ldi Position, 0b00010000
    mov b1, O
    mov b2, O
    mov basic_shift, O
    mov paramNumber, O
    mov REGIME, O
    mov shift_counter, O
    mov new_shift, O

    ldi TMP, 1
    mov ONE, TMP
    mov b0, ONE

    ldi TMP, 4
    mov step, TMP
	; bliding lights timer
	LDI TMP, 0b00001101
	OUT TCCR0, TMP
	LDI TMP, 78                 ; ~0,01 sec
	OUT OCR0, TMP
	LDI TMP, 0b00000010
	OUT TIMSK, TMP

    ; init fast PWM for PD 7
    LDI TMP, 0b01111010
	OUT TCCR2, TMP
	OUT OCR2, O
	call turn_on_small_timer

    ; init fast PWM for PD 4
    LDI TMP, 0b00100001
    OUT TCCR1A, TMP
    LDI TMP, 0b00001010
    OUT TCCR1B, TMP
    OUT OCR1BL, O

    ; ADC init
    LDI TMP, 0b11000110
    OUT ADCSRA, TMP
    LDI TMP, 0b11100101 ; reading from ADCH
	OUT ADMUX, TMP

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
    cp REGIME, ONE
    breq PARAMS_REGIME

    call init_lights
LIGHTS_REGIME:
    cp REGIME, O
    breq LIGHTS_REGIME
PARAMS_REGIME:
    cpi paramNumber, 5
    brlo main
    cp REGIME, O
    breq main

    in TMP, ADCH
    mov new_shift, TMP
    lsr new_shift
    lsr new_shift
    lsr new_shift
    lsr new_shift
    lsr new_shift

    out OCR1BL, TMP
    subi TMP, 255
    out OCR2, TMP

    ldi TMP, 0b11000110
    out ADCSRA, TMP

    mov basic_shift, new_shift
    mov outValue, basic_shift
    call convert_for_7seg
    mov outp_4, outValue
    
    jmp PARAMS_REGIME
; Procedures =================================================
init_lights:
    mov b0, ONE
    mov b1, O
    mov b2, O
    clr shift_counter
basic_shift_loop:
    mov TMP, b0
    rol TMP
    rol b2
    rol b1
    rol b0
    inc shift_counter
    cp shift_counter, basic_shift
    brlo basic_shift_loop
    ret
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
