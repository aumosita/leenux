# Simple Command Queue Test
# Core 0: Write to command queue directly

.globl _start

_start:
    # Initialize
    li sp, 0x200000
    
    # Write to Command Queue
    li t0, 0x20000000     # Command Queue base
    
    # Write command type
    li t1, 1              # CMD_PRINT_CHAR
    sw t1, 0(t0)
    
    # Write arg0 (character)
    li t1, 65             # 'A'
    sw t1, 4(t0)
    
    # Wait a bit
    li t2, 100000
delay:
    addi t2, t2, -1
    bnez t2, delay
    
    # Clear command
    sw zero, 0(t0)
    
# Infinite loop
loop:
    j loop
