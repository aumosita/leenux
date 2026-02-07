# Framebuffer Graphics - Simple Banner
# Using explicit SUB instruction instead of ADDI with negative

.section .text
.globl _start

_start:
    # Stack
    lui sp, 0x90000
    
    # Framebuffer base: 0x10003000
    lui s0, 0x10003
    
    # Red color: 0x00FF0000
    lui s1, 0xFF
    
    # Draw 200 red pixels at top
    li t0, 200         # counter
    mv t1, s0          # address
    li t2, 1           # decrement value
    
banner_loop:
    sw s1, 0(t1)       # write pixel
    addi t1, t1, 4     # next pixel
    sub t0, t0, t2     # counter--
    bne t0, zero, banner_loop
    
    # Draw 200 green pixels
    lui s2, 0x00FF
    slli s2, s2, 8     # Green: 0x0000FF00
    li t0, 200
    
green_loop:
    sw s2, 0(t1)
    addi t1, t1, 4
    sub t0, t0, t2
    bne t0, zero, green_loop
    
    # Draw 200 blue pixels
    li s3, 0xFF        # Blue: 0x000000FF
    li t0, 200
    
blue_loop:
    sw s3, 0(t1)
    addi t1, t1, 4
    sub t0, t0, t2
    bne t0, zero, blue_loop
    
    # Halt
halt:
    j halt
