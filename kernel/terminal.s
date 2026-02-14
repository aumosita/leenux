# Terminal Engine for Leenux OS
# Manages text display, cursor, and scrolling

.section .data
.globl cursor_x
.globl cursor_y
.globl term_scroll_offset

# Terminal state
cursor_x: .word 0
cursor_y: .word 0
term_scroll_offset: .word 0

# Terminal dimensions (80 chars x 30 lines)
.equ TERM_WIDTH, 80
.equ TERM_HEIGHT, 30
.equ TERM_MARGIN_X, 10
.equ TERM_MARGIN_Y, 50

# Colors
.equ COLOR_TEXT, 0x00FFFFFF      # White
.equ COLOR_PROMPT, 0x0000FF00    # Green
.equ COLOR_BG, 0x00001010        # Dark blue

.equ UART_BASE, 0x10000000

.section .text
.globl term_init
.globl term_putchar
.globl term_newline
.globl term_backspace
.globl term_clear
.globl term_scroll

# External dependencies
.extern draw_char
.extern draw_string

#=============================================================================
# term_init: Initialize terminal
#=============================================================================
term_init:
    # Clear cursor position
    la t0, cursor_x
    sw zero, 0(t0)
    la t0, cursor_y
    sw zero, 0(t0)
    la t0, term_scroll_offset
    sw zero, 0(t0)
    
    # Clear screen
    addi sp, sp, -8
    sd ra, 0(sp)
    call term_clear
    
    # Draw initial prompt
    call term_print_prompt
    
    ld ra, 0(sp)
    addi sp, sp, 8
    ret

#=============================================================================
# term_clear: Clear entire screen (Optimized for RV64)
#=============================================================================
term_clear:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    
    # Fill screen with background color
    lui s0, 0x10003          # Framebuffer base
    li s1, COLOR_BG
    
    # Fast clear: write 8 pixels (32 bytes) at once
    # 1024 * 768 = 786432 pixels
    # 786432 / 8 = 98304 iterations
    li t0, 98304
    mv t1, s0
    
    # Construct 64-bit value with two pixels
    slli t2, s1, 32
    or s1, s1, t2            # s1 now has 2 pixels (0x00BBGGRR00BBGGRR)

clear_loop:
    sd s1, 0(t1)
    sd s1, 8(t1)
    sd s1, 16(t1)
    sd s1, 24(t1)
    addi t1, t1, 32
    addi t0, t0, -1
    bnez t0, clear_loop
    
    # Reset cursor
    la t0, cursor_x
    sw zero, 0(t0)
    la t0, cursor_y
    sw zero, 0(t0)
    
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# term_putchar: Display a character at cursor position
#
# Arguments: a0 = character
#=============================================================================
term_putchar:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    
    mv s0, a0                # Save character
    
    # Write to UART via Command Queue (Core 1 will handle it)
    call cmdq_print_char
    
    # Handle special characters
    li t0, 0x0A              # Newline
    beq s0, t0, putchar_newline
    
    li t0, 0x08              # Backspace
    beq s0, t0, putchar_backspace
    
    # Calculate screen position
    la t0, cursor_x
    lw s1, 0(t0)             # s1 = cursor_x
    la t0, cursor_y
    lw s2, 0(t0)             # s2 = cursor_y
    
    # Check if need to wrap
    li t0, TERM_WIDTH
    bge s1, t0, putchar_wrap
    
    # Calculate pixel position
    li t0, 6                 # Character width
    mul a0, s1, t0
    li t0, TERM_MARGIN_X
    add a0, a0, t0           # x = cursor_x * 6 + margin
    
    li t0, 8                 # Character height
    mul a1, s2, t0
    li t0, TERM_MARGIN_Y
    add a1, a1, t0           # y = cursor_y * 8 + margin
    
    # Draw character
    mv a2, s0                # character
    li a3, COLOR_TEXT
    call draw_char
    
    # Advance cursor
    la t0, cursor_x
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    
    j putchar_done
    
putchar_wrap:
    call term_newline
    # Recursive call to print character on new line
    mv a0, s0
    call term_putchar
    j putchar_done
    
putchar_newline:
    call term_newline
    j putchar_done
    
putchar_backspace:
    call term_backspace
    
putchar_done:
    ld s3, 8(sp)
    ld s2, 16(sp)
    ld s1, 24(sp)
    ld s0, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

#=============================================================================
# term_newline: Move cursor to next line
#=============================================================================
term_newline:
    addi sp, sp, -16
    sd ra, 8(sp)
    
    # Set X to 0
    la t0, cursor_x
    sw zero, 0(t0)
    
    # Increment Y
    la t0, cursor_y
    lw t1, 0(t0)
    addi t1, t1, 1
    
    # Check if need to scroll
    li t2, TERM_HEIGHT
    blt t1, t2, newline_no_scroll
    
    # Scroll needed
    call term_scroll
    addi t1, t1, -1          # Stay on last line
    
newline_no_scroll:
    sw t1, 0(t0)
    
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# term_backspace: Delete previous character
#=============================================================================
term_backspace:
    # Get cursor position
    la t0, cursor_x
    lw t1, 0(t0)
    
    # Check if at start of line
    beq t1, zero, backspace_done
    
    # Move cursor back
    addi t1, t1, -1
    sw t1, 0(t0)
    
    # Clear character at that position
    # (Draw space character)
    addi sp, sp, -16
    sd ra, 8(sp)
    
    li a0, 32                # Space
    call term_putchar
    
    # Move cursor back again (putchar advanced it)
    la t0, cursor_x
    lw t1, 0(t0)
    addi t1, t1, -1
    sw t1, 0(t0)
    
    ld ra, 8(sp)
    addi sp, sp, 16
    
backspace_done:
    ret

#=============================================================================
# term_scroll: Scroll terminal content up one line
#=============================================================================
term_scroll:
    # TODO: Implement proper scrolling (copy lines up)
    # For now, just clear screen when full
    addi sp, sp, -16
    sd ra, 8(sp)
    
    call term_clear
    
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# term_print_prompt: Display the command prompt
#=============================================================================
term_print_prompt:
    addi sp, sp, -16
    sd ra, 8(sp)
    
    # Print "leenux> " in green
    la a0, prompt_string
    li a1, 0                 # x = 0
    la t0, cursor_y
    lw t1, 0(t0)
    li t2, 8
    mul a2, t1, t2
    li t2, TERM_MARGIN_Y
    add a2, a2, t2           # y = cursor_y * 8 + margin
    
    li a3, COLOR_PROMPT
    call draw_string
    
    # Update cursor_x to after prompt
    la t0, cursor_x
    li t1, 8                 # "leenux> " = 8 chars
    sw t1, 0(t0)
    
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .rodata
prompt_string:
    .byte "leenux> ", 0
    .align 4
