# RISC-V M Extension Test - Factorial
# Calculates 10! = 3628800
# Tests: MUL instruction

.section .text
.globl _start

_start:
    # Calculate 10!
    addi x10, x0, 10     # n = 10
    addi x11, x0, 1      # result = 1
    
factorial_loop:
    beq x10, x0, done    # if n == 0, done
    mul x11, x11, x10    # result *= n (M extension!)
    addi x10, x10, -1    # n--
    j factorial_loop
    
done:
    # x11 should be 3628800 (0x375F00)
    # Store result for verification
    lui x12, 0x2         # base = 0x2000
    sd x11, 0(x12)
    
    ebreak
