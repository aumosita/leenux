# RISC-V 64I Memory Operations Test
# Tests: SD, LD, SW, LW, SH, LH, SB, LB
# Entry point: 0x1000

.section .text
.globl _start

_start:
    # Set up base address for memory operations
    lui x1, 0x2             # x1 = 0x2000 (base address)
    
    # Test 64-bit store/load (SD/LD)
    addi x2, x0, 0x123      # x2 = 0x123
    slli x2, x2, 32         # x2 = 0x12300000000
    addi x2, x2, 0x456      # x2 = 0x12300000456
    sd x2, 0(x1)            # Store to 0x2000
    ld x3, 0(x1)            # Load from 0x2000, x3 should = x2
    
    # Test 32-bit store/load (SW/LW)
    addi x4, x0, 0x789      # x4 = 0x789
    sw x4, 8(x1)            # Store to 0x2008
    lw x5, 8(x1)            # Load from 0x2008, x5 should = 0x789 (sign-extended)
    lwu x6, 8(x1)           # Load unsigned from 0x2008, x6 = 0x789
    
    # Test 16-bit store/load (SH/LH)
    addi x7, x0, 0x1AB      # x7 = 0x1AB
    sh x7, 16(x1)           # Store to 0x2010
    lh x8, 16(x1)           # Load from 0x2010, x8 should = 0x1AB (sign-extended)
    lhu x9, 16(x1)          # Load unsigned from 0x2010, x9 = 0x1AB
    
    # Test 8-bit store/load (SB/LB)
    addi x10, x0, 0x5C      # x10 = 0x5C
    sb x10, 24(x1)          # Store to 0x2018
    lb x11, 24(x1)          # Load from 0x2018, x11 should = 0x5C
    lbu x12, 24(x1)         # Load unsigned from 0x2018, x12 = 0x5C
    
    # Test write then read back
    addi x13, x0, 42        # x13 = 42
    addi x14, x0, 58        # x14 = 58
    sd x13, 32(x1)          # Store 42 to 0x2020
    sd x14, 40(x1)          # Store 58 to 0x2028
    ld x15, 32(x1)          # x15 = 42
    ld x16, 40(x1)          # x16 = 58
    add x17, x15, x16       # x17 = 100
    
    # Exit with EBREAK
    ebreak
