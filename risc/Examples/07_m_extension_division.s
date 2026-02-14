# RISC-V M Extension Test - Division
# Tests: DIV, DIVU, REM, REMU instructions

.section .text
.globl _start

_start:
    # Test signed division
    addi x1, x0, 100     # x1 = 100
    addi x2, x0, 7       # x2 = 7
    div x3, x1, x2       # x3 = 100 / 7 = 14
    rem x4, x1, x2       # x4 = 100 % 7 = 2
    
    # Test unsigned division
    addi x5, x0, 200     # x5 = 200
    addi x6, x0, 13      # x6 = 13
    divu x7, x5, x6      # x7 = 200 / 13 = 15
    remu x8, x5, x6      # x8 = 200 % 13 = 5
    
    # Test with negative numbers (signed)
    addi x9, x0, -50     # x9 = -50
    addi x10, x0, 7      # x10 = 7
    div x11, x9, x10     # x11 = -50 / 7 = -7
    rem x12, x9, x10     # x12 = -50 % 7 = -1
    
    # Test division by zero (should return -1 for DIV)
    addi x13, x0, 100    # x13 = 100
    addi x14, x0, 0      # x14 = 0
    div x15, x13, x14    # x15 = -1 (0xFFFFFFFFFFFFFFFF)
    
    # Verification: x3=14, x4=2, x7=15, x8=5
    ebreak
