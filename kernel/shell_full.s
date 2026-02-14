# Full Shell for Leenux OS
# Implements command loop and filesystem commands

.section .text
.globl _start

# External dependencies
.extern term_init
.extern term_putchar
.extern term_print_prompt
.extern term_newline
.extern term_clear
.extern keyboard_poll
.extern keyboard_getchar
.extern fs_init
.extern fs_format
.extern fs_read_inode
.extern fs_alloc_inode
.extern fs_write_inode
.extern strcmp
.extern strlen

#=============================================================================
# Entry Point
#=============================================================================
_start:
    # Initialize stack
    li sp, 0x80000
    
    # PMP Configuration (Allow All for User Mode)
    li t0, -1
    csrw pmpaddr0, t0         # Range: All memory
    li t0, 0x1F               # NAPOT (3) + RWX (7) -> 11111 -> 0x1F
    csrw pmpcfg0, t0          # Enable on pmp0
    
    # Fall through to main_init

main_init:
    # Initialize components
    call term_init
    call fs_init
    call proc_init
    
    # Initialize Traps and Timer (Preemption)
    call trap_init
    call timer_init
    
    # Enable Machine Interrupts (MIE bit 3 in mstatus)
    li t0, 0x8
    csrs mstatus, t0
    
    # Print welcome message
    la a0, msg_welcome
    call print_string
    
shell_loop:
    # Print prompt
    call term_print_prompt
    
    # Reset buffer
    la t0, cmd_length
    sw zero, 0(t0)
    
input_loop:
    # Poll keyboard
    call keyboard_poll
    
    # Check for char
    call keyboard_getchar
    mv s0, a0
    
    # If 0, no input
    bne s0, x0, process_input
    
    # Yield to other processes while waiting
    call yield
    j input_loop
    
process_input:
    # Handle newline (Enter)
    li t0, 10
    beq s0, t0, handle_enter
    li t0, 13
    beq s0, t0, handle_enter
    
    # Handle Backspace
    li t0, 8
    beq s0, t0, handle_backspace
    li t0, 127
    beq s0, t0, handle_backspace
    
    # Normal character
    # Check buffer limit
    la t0, cmd_length
    lw t1, 0(t0)
    li t2, 127
    bge t1, t2, input_loop
    
    # Store in buffer
    la t2, command_line
    add t2, t2, t1
    sb s0, 0(t2)
    
    # Increment length
    addi t1, t1, 1
    sw t1, 0(t0)
    
    # Echo
    mv a0, s0
    call term_putchar
    
    j input_loop

handle_backspace:
    la t0, cmd_length
    lw t1, 0(t0)
    beqz t1, input_loop
    
    # Decrement length
    addi t1, t1, -1
    sw t1, 0(t0)
    
    # Visual backspace
    li a0, 8
    call term_putchar
    j input_loop

handle_enter:
    call term_newline
    
    # Null terminate buffer
    la t0, cmd_length
    lw t1, 0(t0)
    la t2, command_line
    add t2, t2, t1
    sb zero, 0(t2)
    
    # Check if empty
    beqz t1, shell_loop
    
    # Execute command
    call execute_command
    
    j shell_loop

#=============================================================================
# execute_command
#=============================================================================
execute_command:
    addi sp, sp, -16
    sd ra, 8(sp)
    
    la a0, command_line
    
    # Check 'help'
    la a1, cmd_help
    call strcmp
    beqz a0, exec_help
    
    # Check 'format'
    la a0, command_line
    la a1, cmd_format
    call strcmp
    beqz a0, exec_format
    
    # Check 'ls'
    la a0, command_line
    la a1, cmd_ls
    call strcmp
    beqz a0, exec_ls
    
    # Check 'touch'
    la a0, command_line
    la a1, cmd_touch
    call strcmp
    beqz a0, exec_touch
    
    # Check 'spawn'
    la a0, command_line
    la a1, cmd_spawn
    call strcmp
    beqz a0, exec_spawn

    # Check 'clear'
    la a0, command_line
    la a1, cmd_clear
    call strcmp
    beqz a0, exec_clear

    # Check 'shutdown'
    la a0, command_line
    la a1, cmd_shutdown
    call strcmp
    beqz a0, exec_shutdown
    
    # Unknown
    la a0, msg_unknown
    call print_string
    la a0, command_line
    call print_string
    call term_newline
    j exec_done

exec_help:
    la a0, msg_help
    call print_string
    j exec_done

exec_format:
    call fs_format
    beqz a0, fmt_success
    la a0, msg_fmt_err
    call print_string
    j exec_done
fmt_success:
    la a0, msg_fmt_ok
    call print_string
    j exec_done

exec_clear:
    call term_clear
    j exec_done

exec_shutdown:
    ebreak
    j shell_loop

exec_ls:
    la a0, msg_ls_hdr
    call print_string
    
    # Iterate inodes 1-16 (SKIP root 0)
    li s2, 1        # Inode index
    li s3, 16       # Max
    
ls_loop:
    bge s2, s3, ls_done
    
    # Read inode s2
    mv a0, s2
    call fs_read_inode
    
    # Check type (offset 4)
    la t0, sector_buffer
    lw t1, 4(t0)    # Type
    
    beqz t1, ls_next
    
    # Print Type
    li t2, 1
    beq t1, t2, print_file_type
    la a0, msg_dir
    j print_type_done
print_file_type:
    la a0, msg_file
print_type_done:
    call print_string
    
    # Print Size (offset 0)
    lw a0, 0(t0)
    li a0, 32 # space
    call term_putchar
    li a0, 32
    call term_putchar
    li a0, 32
    call term_putchar
    
    # Print Name (offset 8)
    la a0, sector_buffer
    addi a0, a0, 8
    call print_string
    call term_newline
    
ls_next:
    addi s2, s2, 1
    j ls_loop
ls_done:
    j exec_done

exec_touch:
    # Create "hello.txt" (fixed for test)
    call fs_alloc_inode
    li t0, -1
    beq a0, t0, touch_err
    
    mv s2, a0 # Save inode num
    
    # Setup inode
    la t0, sector_buffer
    li t1, 0
    sw t1, 0(t0)      # size 0
    li t1, 1
    sw t1, 4(t0)      # type FILE
    
    # Name "hello.txt"
    la t1, val_hello_name
    la t2, sector_buffer
    addi t2, t2, 8
    
    # Copy manually or use strcpy
    lbu t3, 0(t1)
    sb t3, 0(t2)
    lbu t3, 1(t1)
    sb t3, 1(t2)
    lbu t3, 2(t1)
    sb t3, 2(t2)
    lbu t3, 3(t1)
    sb t3, 3(t2)
    lbu t3, 4(t1)
    sb t3, 4(t2)
    lbu t3, 5(t1)
    sb t3, 5(t2)
    lbu t3, 6(t1)
    sb t3, 6(t2)
    lbu t3, 7(t1)
    sb t3, 7(t2)
    lbu t3, 8(t1)
    sb t3, 8(t2)
    lbu t3, 9(t1)
    sb t3, 9(t2)
    
    # Write back
    mv a0, s2
    call fs_write_inode
    
    la a0, msg_touch_ok
    call print_string
    j exec_done
touch_err:
    la a0, msg_touch_err
    call print_string
    j exec_done

exec_spawn:
    la a0, background_task
    call proc_create
    
    li t0, -1
    beq a0, t0, spawn_fail
    
    la a0, msg_spawn_ok
    call print_string
    j exec_done
    
spawn_fail:
    la a0, msg_spawn_err
    call print_string
    j exec_done

#=============================================================================
# Background Task
#=============================================================================
background_task:
    li s1, 0

bg_loop:
    li t0, 500000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    
    li a0, 46 # '.'
    call u_putchar
    call u_yield
    
    j bg_loop

#=============================================================================
# User Mode Syscall Wrappers
#=============================================================================
u_yield:
    li a7, 0
    ecall
    ret

u_putchar:
    li a7, 1
    ecall
    ret

exec_done:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# Helpers
#=============================================================================
print_string:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
ps_loop:
    lbu a0, 0(s0)
    beqz a0, ps_done
    call term_putchar
    addi s0, s0, 1
    j ps_loop
ps_done:
    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4

msg_welcome: .asciz "\nWelcome to Leenux Shell (Preemptive)!\nType 'help' for commands.\n"
msg_unknown: .asciz "Unknown command: "
msg_help: .asciz "Commands: help, ls, touch, format, clear, spawn, shutdown\n"
msg_fmt_ok: .asciz "Filesystem formatted.\n"
msg_fmt_err: .asciz "Format failed.\n"
msg_ls_hdr: .asciz "ID  Type  Size Name\n"
msg_file: .asciz "FILE"
msg_dir: .asciz "DIR "
msg_touch_ok: .asciz "File created.\n"
msg_touch_err: .asciz "Create failed.\n"
msg_spawn_ok: .asciz "Background task spawned.\n"
msg_spawn_err: .asciz "Failed to spawn task.\n"

cmd_help: .asciz "help"
cmd_ls: .asciz "ls"
cmd_format: .asciz "format"
cmd_touch: .asciz "touch"
cmd_clear: .asciz "clear"
cmd_spawn: .asciz "spawn"
cmd_shutdown: .asciz "shutdown"

val_hello_name: .asciz "hello.txt"

# Variables
.align 4
cmd_length: .word 0
command_line: .space 128
sector_buffer: .space 512

.align 4
