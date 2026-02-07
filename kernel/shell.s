# Simple Shell for Leenux OS
# Command-line interface with POSIX-style commands

.section .data
.globl command_line
.globl cmd_length

# Current command line buffer
command_line: .space 128
cmd_length: .word 0

.section .text
.globl shell_init
.globl shell_loop
.globl shell_execute

# External dependencies
.extern term_init
.extern term_putchar
.extern term_newline
.extern term_print_prompt
.extern keyboard_poll
.extern keyboard_getchar

#=============================================================================
# shell_init: Initialize the shell
#=============================================================================
shell_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Initialize terminal
    call term_init
    
    # Clear command buffer
    la t0, cmd_length
    sw zero, 0(t0)
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# shell_loop: Main shell loop
#=============================================================================
shell_loop:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
loop_start:
    # Poll keyboard
    call keyboard_poll
    
    # Check if character available
    call keyboard_getchar
    beq a0, zero, loop_start  # No character, continue
    
    mv s0, a0                 # Save character
    
    # Handle Enter
    li t0, 0x0A
    beq s0, t0, handle_enter
    li t0, 0x0D              # Also check CR
    beq s0, t0, handle_enter
    
    # Handle Backspace
    li t0, 0x08
    beq s0, t0, handle_backspace
    li t0, 0x7F              # DEL
    beq s0, t0, handle_backspace
    
    # Normal character - add to buffer
    la t0, cmd_length
    lw t1, 0(t0)
    
    # Check buffer not full
    li t2, 127
    bge t1, t2, loop_start    # Ignore if full
    
    # Add to command_line
    la t2, command_line
    add t2, t2, t1
    sb s0, 0(t2)
    
    # Increment length
    addi t1, t1, 1
    sw t1, 0(t0)
    
    # Echo character
    mv a0, s0
    call term_putchar
    
    j loop_start

handle_enter:
    # Null-terminate command
    la t0, command_line
    la t1, cmd_length
    lw t2, 0(t1)
    add t0, t0, t2
    sb zero, 0(t0)
    
    # Newline
    call term_newline
    
    # Execute command (if not empty)
    beq t2, zero, enter_skip_exec
    call shell_execute
    
enter_skip_exec:
    # Clear command buffer
    la t0, cmd_length
    sw zero, 0(t0)
    
    # Print new prompt
    call term_print_prompt
    
    j loop_start

handle_backspace:
    # Check if buffer empty
    la t0, cmd_length
    lw t1, 0(t0)
    beq t1, zero, loop_start
    
    # Decrement length
    addi t1, t1, -1
    sw t1, 0(t0)
    
    # Visual backspace
    call term_backspace
    
    j loop_start

#=============================================================================
# shell_execute: Execute the command in command_line
#=============================================================================
shell_execute:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Parse command (simple: just get first word)
    la a0, command_line
    call cmd_dispatch
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_dispatch: Find and execute command
#
# Arguments: a0 = command line string
#=============================================================================
cmd_dispatch:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    mv s0, a0                # Save command line
    
    # Get first word (command name)
    call get_first_word
    mv s1, a0                # s1 = command name
    
    # Check against command table
    la t0, command_table
    
dispatch_loop:
    lw t1, 0(t0)             # Function pointer
    beq t1, zero, dispatch_unknown
    
    lw a0, 4(t0)             # Command name
    mv a1, s1
    call strcmp
    beq a0, zero, dispatch_found
    
    addi t0, t0, 8           # Next entry
    j dispatch_loop
    
dispatch_found:
    lw t1, 0(t0)             # Get function pointer
    jr t1                    # Jump to command function
    j dispatch_done
    
dispatch_unknown:
    # Print "command not found"
    la a2, msg_unknown
    li a0, 0
    la t0, cursor_y
    lw t1, 0(t0)
    li t2, 8
    mul a1, t1, t2
    li t2, 50
    add a1, a1, t2
    lui a3, 0x00FF
    call draw_string
    call term_newline
    
dispatch_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

.section .rodata
msg_unknown:
    .byte "Command not found", 0

# Command dispatch table
command_table:
    .word cmd_echo, str_echo
    .word cmd_clear, str_clear
    .word cmd_help, str_help
    .word cmd_uname, str_uname
    .word cmd_ls, str_ls
    .word cmd_cat, str_cat
    .word cmd_pwd, str_pwd
    .word cmd_cd, str_cd
    .word cmd_free, str_free
    .word cmd_malloc, str_malloc
    .word cmd_memtest, str_memtest
    .word cmd_format, str_format
    .word cmd_df, str_df
    .word cmd_touch, str_touch
    .word cmd_mkdir, str_mkdir
    .word 0, 0               # Terminator

str_echo: .byte "echo", 0
str_clear: .byte "clear", 0
str_help: .byte "help", 0
str_uname: .byte "uname", 0
str_ls: .byte "ls", 0
str_cat: .byte "cat", 0
str_pwd: .byte "pwd", 0
str_cd: .byte "cd", 0
str_free: .byte "free", 0
str_malloc: .byte "malloc", 0
str_memtest: .byte "memtest", 0
str_format: .byte "format", 0
str_df: .byte "df", 0
str_touch: .byte "touch", 0
str_mkdir: .byte "mkdir", 0
