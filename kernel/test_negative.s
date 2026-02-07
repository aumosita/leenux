# Test negative immediate with addi
# Draw framebuffer banner using addi with -1

.section .text
.globl _start

_start:
    # Stack
    lui sp, 0x90000
    
    # Framebuffer base
    lui s0, 0x10003
    
    # Red color
    lui s1, 0xFF
    
    # Draw 300 red pixels using addi -1
    li t0, 300
    mv t1, s0
    
loop:
    sw s1, 0(t1)
    addi t1, t1, 4
    addi t0, t0, -1     # This should now work!
    bne t0, zero, loop
    
    # Draw 300 green pixels
    lui s2, 0x00FF
    slli s2, s2, 8
    li t0, 300
    
green:
    sw s2, 0(t1)
    addi t1, t1, 4
    addi t0, t0, -1
    bne t0, zero, green
    
    # Draw 300 blue pixels
    li s3, 0xFF
    li t0, 300
    
blue:
    sw s3, 0(t1)
    addi t1, t1, 4
    addi t0, t0, -1
    bne t0, zero, blue
    
    # Halt
halt:
    j halt
