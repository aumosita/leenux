# Simple M Extension Test
# No loops, just direct multiplication and division

.section .text
.globl _start

_start:
    # Test MUL
    addi x1, x0, 12      # x1 = 12
    addi x2, x0, 7       # x2 = 7
    mul x3, x1, x2       # x3 = 84 (12 * 7)
    
    # Test DIV
    addi x4, x0, 100     # x4 = 100
    addi x5, x0, 7       # x5 = 7
    div x6, x4, x5       # x6 = 14 (100 / 7)
    
    # Test REM
    rem x7, x4, x5       # x7 = 2 (100 % 7)
    
    # Test DIVU
    addi x8, x0, 200     # x8 = 200
    addi x9, x0, 13      # x9 = 13
    divu x10, x8, x9     # x10 = 15 (200 / 13)
    
    # Test REMU
    remu x11, x8, x9     # x11 = 5 (200 % 13)
    
    # Test MULH (high bits)
    lui x12, 0x10000     # x12 = 0x10000000 (large number)
    lui x13, 0x10000     # x13 = 0x10000000
    mulhu x14, x12, x13  # x14 = high 64 bits of multiplication
    
    # Expected results:
    # x3 = 84
    # x6 = 14
    # x7 = 2
    # x10 = 15
    # x11 = 5
    
    ebreak
