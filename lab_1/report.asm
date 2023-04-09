_main	
    LSR R0
    LDI R1, 0x01
    AND R1, R0
    LSR R1
loop
    ROR RO
    RJMP loop
summ
    add r3, r0
    adc r4, r1
    adc r5, r2
