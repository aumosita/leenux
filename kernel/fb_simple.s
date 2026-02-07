# Ultra-simple framebuffer test
# Just write 10 pixels manually

.section .text
.globl _start

_start:
    # Stack
    lui sp, 0x90000
    
    # Framebuffer base: 0x10003000
    lui t0, 0x10003
    
    # Red color: 0xFF0000 (RGB) or 0x00FF0000
    lui t1, 0xFF
    
    # Write 10 pixels
    sw t1, 0(t0)
    sw t1, 4(t0)
    sw t1, 8(t0)
    sw t1, 12(t0)
    sw t1, 16(t0)
    sw t1, 20(t0)
    sw t1, 24(t0)
    sw t1, 28(t0)
    sw t1, 32(t0)
    sw t1, 36(t0)
    
    # Halt
halt:
    j halt
