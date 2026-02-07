# Minimal Shell for Terminal Bridge Testing
# Uses UART for I/O, reports commands back to Swift

.section .text
.globl _start

_start:
    # Stack setup
    li sp, 0x80000
    
    # Print welcome
    la a0, msg_welcome
    call uart_print
    
shell_loop:
    # Print prompt
    la a0, msg_prompt
    call uart_print
    
    # Wait for input simulation
    # (In real system, this would read from UART RX)
    # For now, just echo a test command
    la a0, msg_test_cmd
    call uart_print
    
    # Print newline
    li a0, 0x0A
    call uart_putchar
    
    # Execute test command
    la a0, msg_format_result
    call uart_print
    
    # Loop back
    j shell_loop

# UART print string (null-terminated)
# a0 = string address
uart_print:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
.uart_print_loop:
    lbu a0, 0(s0)
    beqz a0, .uart_print_done
    call uart_putchar
    addi s0, s0, 1
    j .uart_print_loop
    
.uart_print_done:
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# UART put single character
# a0 = character
uart_putchar:
    lui t0, 0x10000        # UART base 0x10000000
    sb a0, 0(t0)
    ret

.section .data
msg_welcome:
    .asciz "Leenux Shell v0.1\n"
msg_prompt:
    .asciz "leenux> "
msg_test_cmd:
    .asciz "format"
msg_format_result:
    .asciz "Formatting disk with SFS...\nDone!\n"
