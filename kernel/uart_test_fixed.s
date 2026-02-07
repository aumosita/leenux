# UART Test - Use LUI + ADDI for correct 32-bit address
.section .text
.globl _start

_start:
    # Load UART base 0x10000000 correctly
    lui t0, 0x10000     # Upper 20 bits: 0x10000 << 12 = 0x10000000
    
    li t1, 0x48         # 'H'
    sb t1, 0(t0)
    
    li t1, 0x69         # 'i'
    sb t1, 0(t0)
    
    li t1, 0x21         # '!'
    sb t1, 0(t0)
    
    li t1, 0x0A         # '\n'
    sb t1, 0(t0)
    
loop:
    nop
    j loop
