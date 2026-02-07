# RISC-V M Extension Test - GCD (Greatest Common Divisor)
# Euclidean algorithm using division
# Tests: REM instruction

.section .text
.globl _start

_start:
    # Calculate GCD(48, 18) = 6
    addi x10, x0, 48     # a = 48
    addi x11, x0, 18     # b = 18
    
gcd_loop:
    beq x11, x0, done    # if b == 0, done
    remu x12, x10, x11   # temp = a % b
    addi x10, x11, 0     # a = b
    addi x11, x12, 0     # b = temp
    j gcd_loop
    
done:
    # x10 should be 6 (GCD result)
    
    # Test with another pair: GCD(100, 35) = 5
    addi x13, x0, 100    # a = 100
    addi x14, x0, 35     # b = 35
    
gcd_loop2:
    beq x14, x0, done2
    remu x15, x13, x14
    addi x13, x14, 0
    addi x14, x15, 0
    j gcd_loop2
    
done2:
    # x13 should be 5
    
    ebreak
