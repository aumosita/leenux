# RISC-V 64I Arithmetic Test
# Tests: ADDI, ADD, SUB, AND, OR, XOR, SLL, SRL
# Entry point: 0x1000

.section .text
.globl _start

_start:
    # Initialize values
    addi x1, x0, 42         # x1 = 42
    addi x2, x0, 58         # x2 = 58
    
    # Test ADD
    add x3, x1, x2          # x3 = 100 (42 + 58)
    
    # Test SUB
    sub x4, x2, x1          # x4 = 16 (58 - 42)
    
    # Test AND
    and x5, x1, x2          # x5 = 40 (42 & 58 = 0x2A & 0x3A)
    
    # Test OR
    or x6, x1, x2           # x6 = 60 (42 | 58 = 0x2A | 0x3A)
    
    # Test XOR
    xor x7, x1, x2          # x7 = 20 (42 ^ 58 = 0x2A ^ 0x3A)
    
    # Test SLL (Shift Left Logical)
    addi x8, x0, 2          # x8 = 2
    sll x9, x1, x8          # x9 = 168 (42 << 2)
    
    # Test SRL (Shift Right Logical)
    srl x10, x2, x8         # x10 = 14 (58 >> 2)
    
    # Test immediate versions
    addi x11, x1, 10        # x11 = 52 (42 + 10)
    andi x12, x2, 15        # x12 = 10 (58 & 15)
    ori x13, x1, 7          # x13 = 47 (42 | 7)
    xori x14, x2, 15        # x14 = 53 (58 ^ 15)
    
    # Test shifts with immediate
    slli x15, x1, 3         # x15 = 336 (42 << 3)
    srli x16, x2, 2         # x16 = 14 (58 >> 2)
    
    # Exit with EBREAK
    ebreak
