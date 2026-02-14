# Simple floating-point test
# 3.14 + 2.71 = 5.85

.section .data
pi:     .float 3.14159
e:      .float 2.71828
result: .float 0.0

.section .text
.globl _start

_start:
    # Load address of data
    la a0, pi
    la a1, e
    la a2, result
    
    # Load floats into FP registers
    flw f1, 0(a0)       # f1 = 3.14159
    flw f2, 0(a1)       # f2 = 2.71828
    
    # Addition
    fadd.s f3, f1, f2   # f3 = 5.85987
    
    # Store result
    fsw f3, 0(a2)
    
    # Convert to integer for verification
    fcvt.w.s a3, f3     # a3 = 5
    
    # Multiplication
    fmul.s f4, f1, f2   # f4 = 3.14 * 2.71 ≈ 8.54
    fcvt.w.s a4, f4     # a4 = 8
    
    # Division
    fdiv.s f5, f1, f2   # f5 = 3.14 / 2.71 ≈ 1.16
    fcvt.w.s a5, f5     # a5 = 1
    
    # Square root
    fsqrt.s f6, f1      # f6 = sqrt(3.14) ≈ 1.77
    fcvt.w.s a6, f6     # a6 = 1
    
    ebreak
