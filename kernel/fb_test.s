# Simple framebuffer test - Version 2
# Using subtraction instead of negative addi

.section .text
.globl _start

_start:
    # Stack
    lui sp, 0x90000
    
    # Framebuffer base: 0x10003000
    lui t0, 0x10003
    
    # Counter: start at 0, go to 100
    li t1, 0
    li t2, 100
    
    # Red color: 0x00FF0000
    lui t3, 0x00FF
    
loop:
    # Calculate address: base + (counter * 4)
    slli t4, t1, 2     # counter * 4
    add t4, t0, t4     # + base
    
    # Write red pixel
    sw t3, 0(t4)
    
    # Increment counter
    addi t1, t1, 1
    
    # Check if done
    blt t1, t2, loop
    
    # Halt
halt:
    j halt
