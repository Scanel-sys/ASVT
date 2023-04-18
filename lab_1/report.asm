# циклический сдвиг вправо 8-разрядного числа
_main	
    LDI R1, 0x01
    AND R1, R0
    LSR R1
    LSR R0
loop
    ROR RO
    RJMP loop
# сложение 2х 24-битных чисел
summ
    add r3, r0
    adc r4, r1
    adc r5, r2
