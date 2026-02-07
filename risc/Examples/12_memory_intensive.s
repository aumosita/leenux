# Memory-intensive test for bus arbitration
# All cores access memory frequently

.section .text
.globl _start

_start:
    # Load from memory
    lui x1, 0x2          # base = 0x2000
    ld x2, 0(x1)         # load from 0x2000
    ld x3, 8(x1)         # load from 0x2008
    ld x4, 16(x1)        # load from 0x2010
    
    # Compute
    add x5, x2, x3
    add x6, x4, x5
    
    # Store back
    sd x5, 24(x1)        # store to 0x2018
    sd x6, 32(x1)        # store to 0x2020
    
    # More loads
    ld x7, 40(x1)
    ld x8, 48(x1)
    
    ebreak
