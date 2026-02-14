# Simplified Shell - UART only, no framebuffer
.section .text
.globl _start

.equ UART_BASE, 0x10000000

_start:
    # Initialize stack
    li sp, 0x80000
    
    # Print welcome message
    la a0, msg_welcome
    call uart_print
    
    # Print prompt
    la a0, msg_prompt
    call uart_print
    
    # Halt
halt_loop:
    j halt_loop

# uart_print: Print null-terminated string
# Input: a0 = string address
uart_print:
    li t0, UART_BASE
uart_loop:
    lb t1, 0(a0)
    beqz t1, uart_done
    sb t1, 0(t0)
    addi a0, a0, 1
    j uart_loop
uart_done:
    ret

.section .data
msg_welcome: .asciz "Welcome to Leenux OS!\n"
msg_prompt: .asciz "leenux> "
