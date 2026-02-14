# Simple UART test
.section .text
.globl _start

_start:
    # Print 'H' to UART
    li a0, 72              # 'H'
    li a1, 0x10000000      # UART base
    sb a0, 0(a1)           # Write to TX register
    
    # Print 'i' 
    li a0, 105             # 'i'
    sb a0, 0(a1)
    
    # Print newline
    li a0, 10              # '\n'
    sb a0, 0(a1)
    
    # Halt loop
halt:
    j halt
