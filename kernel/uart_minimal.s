# Minimal UART test - write 'H' directly
.section .text
.globl _start

_start:
    li t0, 0x10000000       # UART base
    li t1, 0x48             # 'H'
    sb t1, 0(t0)
    
    li t1, 0x69             # 'i'
    sb t1, 0(t0)
    
    li t1, 0x0A             # '\n'
    sb t1, 0(t0)
    
loop:
    nop
    j loop
