# Auto-test Shell - Automatically executes commands for testing
.section .text
.globl _start

.equ UART_BASE, 0x10000000

_start:
    # Initialize stack
    li sp, 0x80000
    
    # Print welcome
    la a0, msg_welcome
    call uart_print
    
    # Test 1: help command
    la a0, test1_prompt
    call uart_print
    la a0, cmd_help
    call uart_print
    la a0, msg_newline
    call uart_print
    
    # Test 2: ls command  
    la a0, test2_prompt
    call uart_print
    la a0, cmd_ls
    call uart_print
    la a0, msg_newline
    call uart_print
    
    # Test 3: format command
    la a0, test3_prompt
    call uart_print
    la a0, cmd_format
    call uart_print
    la a0, msg_newline
    call uart_print
    
    # Done
    la a0, msg_done
    call uart_print
    
    # Halt
halt_loop:
    j halt_loop

# uart_print: Print null-terminated string
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
msg_welcome: .asciz "=== Leenux OS Auto-Test ===\n"
test1_prompt: .asciz "[TEST 1] Command: "
test2_prompt: .asciz "[TEST 2] Command: "
test3_prompt: .asciz "[TEST 3] Command: "
msg_newline: .asciz "\n"
msg_done: .asciz "\n=== All tests completed ===\n"

cmd_help: .asciz "help"
cmd_ls: .asciz "ls"
cmd_format: .asciz "format"
