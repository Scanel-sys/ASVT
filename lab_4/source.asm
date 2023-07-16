;= Start 	macro.inc ========================================
.def b0 = R24
.def b1 = R23
.def b2 = R22
.def TMP_INTR = R17
.def TMP = R16
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
.org $002
	JMP EXT_INT0             ; (INT0) Regime changer    / PD2
.org 0x004
    JMP EXT_INT1			 ; (INT1) Parameter chooser / PD3

; Interrupts =================================================
EXT_INT0:
    reti

EXT_INT1:
    reti

; END Interrupts =============================================

; Board Init =================================================
init_board:

    ; init PORTS
    CLR TMP
    out DDRA, TMP
    out DDRB, TMP
    out DDRC, TMP
    out PORTA, TMP
    out PORTB, TMP
    out PORTC, TMP

    ; init vars
    MOV O, TMP
    MOV b1, TMP
    MOV b2, TMP
    MOV basic_shift, TMP

    
    LDI TMP, 1
    MOV ONE, TMP
    MOV b0, ONE
    MOV step, ONE

    LDI TMP, 3
    MOV frequency, TMP


    ; INTERRUPTS init
    LDI TMP, 0x0F
    OUT MCUCR, TMP      ; Настройка прерываний int0 и int1 на условие 0/1
    LDI TMP, 0b11000000
    OUT GICR, TMP       ; Разрешение прерываний int0 и int1
    OUT GIFR, TMP       ; Предотвращение срабатывания int0 и int1 при
    			        ; включении прерываний

; End Board Init =============================================

; Main =======================================================
main:


; Procedures =================================================
