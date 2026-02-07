# Very simple UART test
# Just print "A" repeatedly

.section .text
.globl _start

_start:
    # UART base
    lui t0, 0x10000
    
loop:
    # Print 'A'
    li t1, 65
    sb t1, 0(t0)
    
    # Small delay (just some NOPs)
    nop
    nop
    nop
    nop
    
    # Loop
    j loop
