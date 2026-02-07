# RISC-V Test: UART Output for Bridge Testing
# This kernel simply outputs text via UART for Swift bridge validation

.section .text
.globl _start

_start:
    # Initialize stack
    li sp, 0x80000

    # Print welcome message
    la a0, msg_welcome
    call print_string
    
    # Print prompt
    la a0, msg_prompt
    call print_string
    
    # Infinite loop (wait for input - will be handled by Swift later)
loop:
    nop
    j loop

# Print null-terminated string to UART
# a0 = string address
print_string:
    li t0, 0x10000000       # UART base address
    
.print_loop:
    lbu t1, 0(a0)           # Load byte
    beqz t1, .print_done    # If null, done
    sb t1, 0(t0)            # Write to UART
    addi a0, a0, 1          # Next character
    j .print_loop
    
.print_done:
    ret

.section .data
msg_welcome:
    .asciz "Leenux Kernel v0.1\n"
msg_prompt:
    .asciz "leenux> "
