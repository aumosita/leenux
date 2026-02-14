# Simple branch test without labels
# Multiple sequential branches

.section .text
.globl _start

_start:
    # Test 1: BEQ (should not take)
    addi x1, x0, 10
    addi x2, x0, 20
    beq x1, x2, skip1    # not taken
    addi x3, x0, 1       # executed
    
skip1:
    # Test 2: BNE (should take)
    bne x1, x2, skip2    # taken
    addi x4, x0, 99      # not executed
    
skip2:
    # Test 3: BLT (should take)
    blt x1, x2, skip3    # taken (10 < 20)
    addi x5, x0, 99      # not executed
    
skip3:
    # Test 4: BGE (should not take)
    bge x1, x2, skip4    # not taken (10 >= 20 is false)
    addi x6, x0, 2       # executed
    
skip4:
    # Result: x3=1, x6=2
    ebreak
