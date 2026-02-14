# Test: Only write to Command Queue (no direct UART)

.globl _start

_start:
    li sp, 0x200000
    
    # Command Queue
    li t0, 0x20000000
    
    # Command: Print 'X'
    li t1, 1
    sw t1, 0(t0)
    li t1, 88             # 'X'
    sw t1, 4(t0)
    
    # Wait
    li t2, 50000
delay:
    addi t2, t2, -1
    bnez t2, delay

loop:
    j loop
