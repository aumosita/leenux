# Test program for Core 0: Write to Command Queue
# This program writes commands to shared memory (0x20000000)
# for Core 1 to process

.globl _start

_start:
    # Initialize
    li sp, 0x200000       # Stack at 2MB
    
    # Print startup message
    li a0, 0x10000000     # UART base
    li a1, 67             # 'C'
    sb a1, 0(a0)
    li a1, 48             # '0'
    sb a1, 0(a0)
    li a1, 10             # '\n'
    sb a1, 0(a0)
    
    # Command Queue test
    li t0, 0x20000000     # Command Queue base
    
    # Command 1: Print 'A'
    li t1, 1              # Command type: PRINT_CHAR
    sw t1, 0(t0)          # Write command type
    li t1, 65             # 'A'
    sw t1, 4(t0)          # Write char
    
    # Wait a bit (simple delay)
    li t2, 10000
delay1:
    addi t2, t2, -1
    bnez t2, delay1
    
    # Clear command
    sw zero, 0(t0)
    
    # Command 2: Print 'B'
    li t1, 1
    sw t1, 0(t0)
    li t1, 66             # 'B'
    sw t1, 4(t0)
    
    # Wait
    li t2, 10000
delay2:
    addi t2, t2, -1
    bnez t2, delay2
    
    # Clear command
    sw zero, 0(t0)
    
    # Command 3: Print '!' and newline
    li t1, 1
    sw t1, 0(t0)
    li t1, 33             # '!'
    sw t1, 4(t0)
    
    li t2, 10000
delay3:
    addi t2, t2, -1
    bnez t2, delay3
    
    sw zero, 0(t0)
    
    li t1, 1
    sw t1, 0(t0)
    li t1, 10             # '\n'
    sw t1, 4(t0)

# Infinite loop
loop:
    j loop
