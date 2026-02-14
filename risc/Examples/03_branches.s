# RISC-V 64I Branch Instructions Test
# Tests: BEQ, BNE, BLT, BGE, BLTU, BGEU
# Entry point: 0x1000

.section .text
.globl _start

_start:
    addi x10, x0, 0         # x10 = 0 (test counter)
    
    # Test BEQ (Branch if Equal)
    addi x1, x0, 42         # x1 = 42
    addi x2, x0, 42         # x2 = 42
    bne x1, x2, fail        # Should NOT branch
    addi x10, x10, 1        # x10 = 1 (test passed)
    
    # Test BNE (Branch if Not Equal)
    addi x3, x0, 42         # x3 = 42
    addi x4, x0, 58         # x4 = 58
    beq x3, x4, fail        # Should NOT branch
    addi x10, x10, 1        # x10 = 2 (test passed)
    
    # Test BLT (Branch if Less Than - signed)
    addi x5, x0, 10         # x5 = 10
    addi x6, x0, 20         # x6 = 20
    bge x5, x6, fail        # Should NOT branch (10 < 20)
    addi x10, x10, 1        # x10 = 3 (test passed)
    
    # Test BGE (Branch if Greater or Equal - signed)
    addi x7, x0, 30         # x7 = 30
    addi x8, x0, 20         # x8 = 20
    blt x7, x8, fail        # Should NOT branch (30 >= 20)
    addi x10, x10, 1        # x10 = 4 (test passed)
    
    # Test BLTU (Branch if Less Than - unsigned)
    addi x9, x0, 5          # x9 = 5
    addi x11, x0, 15        # x11 = 15
    bgeu x9, x11, fail      # Should NOT branch (5 < 15 unsigned)
    addi x10, x10, 1        # x10 = 5 (test passed)
    
    # Test BGEU (Branch if Greater or Equal - unsigned)
    addi x12, x0, 25        # x12 = 25
    addi x13, x0, 15        # x13 = 15
    bltu x12, x13, fail     # Should NOT branch (25 >= 15 unsigned)
    addi x10, x10, 1        # x10 = 6 (test passed)
    
    # Test actual branching - BEQ should branch
    addi x14, x0, 100       # x14 = 100
    addi x15, x0, 100       # x15 = 100
    beq x14, x15, branch_taken
    j fail                  # Should not reach here
    
branch_taken:
    addi x10, x10, 1        # x10 = 7 (test passed)
    
    # Test BNE should branch
    addi x16, x0, 50        # x16 = 50
    addi x17, x0, 60        # x17 = 60
    bne x16, x17, branch_taken2
    j fail                  # Should not reach here
    
branch_taken2:
    addi x10, x10, 1        # x10 = 8 (test passed)
    
    # All tests passed
    j success
    
fail:
    # Set failure marker
    addi x10, x0, -1        # x10 = -1 (failure)
    ebreak
    
success:
    # x10 should be 8 if all tests passed
    ebreak
