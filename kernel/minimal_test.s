# Minimal test for addi -1

.section .text
.globl _start

_start:
    # Set counter to 5
    li t0, 5
    
    # Decrement using addi -1
    addi t0, t0, -1    # Should be 4
    addi t0, t0, -1    # Should be 3
    addi t0, t0, -1    # Should be 2
    addi t0, t0, -1    # Should be 1
    addi t0, t0, -1    # Should be 0
    
    # Halt
halt:
    j halt
