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

# Command Queue Helper Functions for Kernel
# 
# Provides abstraction layer for I/O operations via Command Queue
# Core 0 (CPU) writes commands, Core 1 (I/O processor) executes

.globl cmdq_print_char
.globl cmdq_write_pixel
.globl cmdq_flush_fb

# Command Queue Base
.equ CMDQ_BASE, 0x20000000
.equ CMDQ_TYPE, 0x00
.equ CMDQ_ARG0, 0x04
.equ CMDQ_ARG1, 0x08
.equ CMDQ_ARG2, 0x0C

# Command Types
.equ CMD_NOP, 0
.equ CMD_PRINT_CHAR, 1
.equ CMD_WRITE_PIXEL, 2
.equ CMD_FLUSH_FB, 3

# cmdq_print_char: Print character via Command Queue
# Arguments:
#   a0 = character to print
# Preserves: all registers except t0-t2
cmdq_print_char:
    li t0, CMDQ_BASE
    
    # Wait for queue to be free
1:  lw t1, CMDQ_TYPE(t0)
    bnez t1, 1b           # Spin if busy
    
    # Write command
    sw a0, CMDQ_ARG0(t0)  # Store char
    li t1, CMD_PRINT_CHAR
    sw t1, CMDQ_TYPE(t0)  # Trigger command
    
    # Small delay to let I/O core process
    li t2, 10
2:  addi t2, t2, -1
    bnez t2, 2b
    
    ret

# cmdq_write_pixel: Write pixel to framebuffer
# Arguments:
#   a0 = x coordinate
#   a1 = y coordinate
#   a2 = color (RGBA)
# Preserves: all registers except t0-t2
cmdq_write_pixel:
    li t0, CMDQ_BASE
    
    # Wait for queue
1:  lw t1, CMDQ_TYPE(t0)
    bnez t1, 1b
    
    # Write arguments
    sw a0, CMDQ_ARG0(t0)  # x
    sw a1, CMDQ_ARG1(t0)  # y
    sw a2, CMDQ_ARG2(t0)  # color
    
    # Trigger
    li t1, CMD_WRITE_PIXEL
    sw t1, CMDQ_TYPE(t0)
    
    # Small delay
    li t2, 10
2:  addi t2, t2, -1
    bnez t2, 2b
    
    ret

# cmdq_flush_fb: Flush framebuffer
# Preserves: all registers except t0-t2
cmdq_flush_fb:
    li t0, CMDQ_BASE
    
    # Wait for queue
1:  lw t1, CMDQ_TYPE(t0)
    bnez t1, 1b
    
    # Trigger
    li t1, CMD_FLUSH_FB
    sw t1, CMDQ_TYPE(t0)
    
    # Small delay
    li t2, 10
2:  addi t2, t2, -1
    bnez t2, 2b
    
    ret

# Process Management for Leenux OS

.section .data
.globl proc_table, current_proc, proc_count

.equ MAX_PROCESSES, 4
.equ STACK_SIZE, 1024
.equ PROC_STATE_UNUSED, 0
.equ PROC_STATE_READY, 1
.equ PROC_STATE_RUNNING, 2
.equ PCB_SIZE, 32
.equ PCB_OFFSET_PID, 0
.equ PCB_OFFSET_STATE, 4
.equ PCB_OFFSET_SP, 8
.equ PCB_OFFSET_STACK, 16

.align 3
proc_table: .space MAX_PROCESSES * PCB_SIZE
current_proc: .word -1
proc_count: .word 0

.align 3
proc_stacks: .space MAX_PROCESSES * STACK_SIZE

.section .text
.globl proc_init, proc_create, schedule, yield, switch_context

proc_init:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, proc_table
    li t1, MAX_PROCESSES
    li t2, 0
    li t3, PROC_STATE_UNUSED
init_loop:
    sw t3, PCB_OFFSET_STATE(t0)
    addi t0, t0, PCB_SIZE
    addi t2, t2, 1
    blt t2, t1, init_loop
    la t0, proc_table
    li t1, 0
    sw t1, PCB_OFFSET_PID(t0)
    li t2, PROC_STATE_RUNNING
    sw t2, PCB_OFFSET_STATE(t0)
    la t0, current_proc
    sw t1, 0(t0)
    la t0, proc_count
    li t1, 1
    sw t1, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

proc_create:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    mv s0, a0
    la t0, proc_table
    li t1, 0
    li t2, MAX_PROCESSES
find_free:
    lw t3, PCB_OFFSET_STATE(t0)
    li t4, PROC_STATE_UNUSED
    beq t3, t4, found_slot
    addi t0, t0, PCB_SIZE
    addi t1, t1, 1
    blt t1, t2, find_free
    li a0, -1
    j proc_create_end
found_slot:
    sw t1, PCB_OFFSET_PID(t0)
    li t3, PROC_STATE_READY
    sw t3, PCB_OFFSET_STATE(t0)
    la t4, proc_stacks
    addi t5, t1, 1
    li t6, STACK_SIZE
    mul t5, t5, t6
    add t4, t4, t5
    sd t4, PCB_OFFSET_STACK(t0)  # Use sd for 64-bit pointer
    addi t4, t4, -112
    sd t4, PCB_OFFSET_SP(t0)
    sd s0, 0(t4)                 # s0 restored on first switch
    la t6, k_to_user
    sd t6, 96(t4)                # ra restored on first switch
    la t5, proc_count
    lw t6, 0(t5)
    addi t6, t6, 1
    sw t6, 0(t5)
    mv a0, t1
proc_create_end:
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

schedule:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, current_proc
    lw t1, 0(t0)
    addi t2, t1, 1
    li t3, MAX_PROCESSES
    rem t2, t2, t3
    li t5, 0
scan_loop:
    bge t5, t3, no_switch
    la t6, proc_table
    li a1, PCB_SIZE
    mul a2, t2, a1
    add t6, t6, a2
    lw a3, PCB_OFFSET_STATE(t6)
    li a4, PROC_STATE_READY
    beq a3, a4, switch_to
    addi t2, t2, 1
    rem t2, t2, t3
    addi t5, t5, 1
    j scan_loop
no_switch:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
switch_to:
    la a0, current_proc
    sw t2, 0(a0)
    li a1, PROC_STATE_RUNNING
    sw a1, PCB_OFFSET_STATE(t6)
    li a2, -1
    beq t1, a2, first_run
    la a3, proc_table
    li a4, PCB_SIZE
    mul a5, t1, a4
    add a3, a3, a5
    li a6, PROC_STATE_READY
    sw a6, PCB_OFFSET_STATE(a3)
    addi a0, a3, PCB_OFFSET_SP
    ld a1, PCB_OFFSET_SP(t6)
    call switch_context
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
first_run:
    ld a1, PCB_OFFSET_SP(t6)
    j restore_context

yield:
    j schedule

switch_context:
    addi sp, sp, -112
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd s2, 16(sp)
    sd s3, 24(sp)
    sd s4, 32(sp)
    sd s5, 40(sp)
    sd s6, 48(sp)
    sd s7, 56(sp)
    sd s8, 64(sp)
    sd s9, 72(sp)
    sd s10, 80(sp)
    sd s11, 88(sp)
    sd ra, 96(sp)
    sd sp, 0(a0)
restore_context:
    mv sp, a1
    ld s0, 0(sp)
    ld s1, 8(sp)
    ld s2, 16(sp)
    ld s3, 24(sp)
    ld s4, 32(sp)
    ld s5, 40(sp)
    ld s6, 48(sp)
    ld s7, 56(sp)
    ld s8, 64(sp)
    ld s9, 72(sp)
    ld s10, 80(sp)
    ld s11, 88(sp)
    ld ra, 96(sp)
    addi sp, sp, 112
    ret

k_to_user:
    csrw mepc, s0
    csrr t0, mstatus
    li t1, 0x1800
    csrc mstatus, t1
    li t1, 0x80
    csrs mstatus, t1
    mret

# Trap Handler for Leenux OS

.section .text
.globl trap_init, trap_vector

trap_init:
    la t0, trap_vector
    csrw mtvec, t0
    ret

.align 4
trap_vector:
    addi sp, sp, -256
    sd ra, 0(sp)
    sd sp, 8(sp)
    sd gp, 16(sp)
    sd tp, 24(sp)
    sd t0, 32(sp)
    sd t1, 40(sp)
    sd t2, 48(sp)
    sd s0, 56(sp)
    sd s1, 64(sp)
    sd a0, 72(sp)
    sd a1, 80(sp)
    sd a2, 88(sp)
    sd a3, 96(sp)
    sd a4, 104(sp)
    sd a5, 112(sp)
    sd a6, 120(sp)
    sd a7, 128(sp)
    sd s2, 136(sp)
    sd s3, 144(sp)
    sd s4, 152(sp)
    sd s5, 160(sp)
    sd s6, 168(sp)
    sd s7, 176(sp)
    sd s8, 184(sp)
    sd s9, 192(sp)
    sd s10, 200(sp)
    sd s11, 208(sp)
    sd t3, 216(sp)
    sd t4, 224(sp)
    sd t5, 232(sp)
    sd t6, 240(sp)
    
    csrr t0, mcause
    li t1, 0x8000000000000000
    and t2, t0, t1
    beqz t2, handle_exception
    
    not t1, t1
    and t0, t0, t1
    
    li t1, 7
    beq t0, t1, handle_timer
    j trap_exit

handle_timer:
    call timer_handler
    j trap_exit

handle_exception:
    li t1, 8
    beq t0, t1, handle_syscall
    ebreak # Crash on unknown exception
    j handle_exception

handle_syscall:
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    
    li t0, 0
    beq a7, t0, sys_yield
    li t0, 1
    beq a7, t0, sys_putchar
    li t0, 2
    beq a7, t0, sys_exit
    j trap_exit

sys_yield:
    call schedule
    j trap_exit

sys_putchar:
    call term_putchar
    j trap_exit
    
sys_exit:
    j sys_yield

trap_exit:
    ld ra, 0(sp)
    ld gp, 16(sp)
    ld tp, 24(sp)
    ld t0, 32(sp)
    ld t1, 40(sp)
    ld t2, 48(sp)
    ld s0, 56(sp)
    ld s1, 64(sp)
    ld a0, 72(sp)
    ld a1, 80(sp)
    ld a2, 88(sp)
    ld a3, 96(sp)
    ld a4, 104(sp)
    ld a5, 112(sp)
    ld a6, 120(sp)
    ld a7, 128(sp)
    ld s2, 136(sp)
    ld s3, 144(sp)
    ld s4, 152(sp)
    ld s5, 160(sp)
    ld s6, 168(sp)
    ld s7, 176(sp)
    ld s8, 184(sp)
    ld s9, 192(sp)
    ld s10, 200(sp)
    ld s11, 208(sp)
    ld t3, 216(sp)
    ld t4, 224(sp)
    ld t5, 232(sp)
    ld t6, 240(sp)
    addi sp, sp, 256
    mret

# RISC-V Timer Driver (CLINT)

.section .data
.align 3
.equ CLINT_BASE, 0x10001000
.equ CLINT_MTIME, 0x00
.equ CLINT_MTIMECMP, 0x08
.equ CLINT_CTRL, 0x10
.equ TIMER_INTERVAL, 100000

.section .text
.globl timer_init, timer_handler

timer_init:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t0, CLINT_BASE
    ld t2, CLINT_MTIME(t0)
    li t3, TIMER_INTERVAL
    add t2, t2, t3
    sd t2, CLINT_MTIMECMP(t0)
    li t3, 1
    sb t3, CLINT_CTRL(t0)
    li t0, 0x80
    csrs mie, t0
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

timer_handler:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t0, CLINT_BASE
    li t1, 3
    sb t1, CLINT_CTRL(t0)
    ld t2, CLINT_MTIMECMP(t0)
    li t3, TIMER_INTERVAL
    add t2, t2, t3
    sd t2, CLINT_MTIMECMP(t0)
    call schedule
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# Disk Driver - MMIO Block Device

.section .data
.equ DISK_BASE, 0x15000000
.equ DISK_SECTOR, 0x15000000
.equ DISK_BUFFER, 0x15000004
.equ DISK_COMMAND, 0x15000008
.equ DISK_STATUS, 0x1500000C
.equ CMD_READ, 0x01
.equ CMD_WRITE, 0x02
.equ STATUS_IDLE, 0x00
.equ STATUS_BUSY, 0x01
.equ STATUS_DONE, 0x02
.equ STATUS_ERROR, 0xFF
.equ TOTAL_SECTORS, 65536

.globl disk_initialized
disk_initialized: .word 0

.section .text
.globl disk_init, disk_read_sector, disk_write_sector, disk_wait

disk_init:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t0, DISK_STATUS
    lbu t1, 0(t0)
    la t0, disk_initialized
    li t1, 1
    sw t1, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

disk_read_sector:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    mv s1, a1
    la t0, disk_initialized
    lw t1, 0(t0)
    beqz t1, drs_error
    li t0, TOTAL_SECTORS
    bgeu s0, t0, drs_error
    call disk_wait
    bnez a0, drs_error
    li t0, DISK_SECTOR
    sw s0, 0(t0)
    li t0, DISK_BUFFER
    sw s1, 0(t0)
    li t0, DISK_COMMAND
    li t1, CMD_READ
    sb t1, 0(t0)
    call disk_wait
    bnez a0, drs_error
    li a0, 0
    j drs_done
drs_error:
    li a0, -1
drs_done:
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

disk_write_sector:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    mv s1, a1
    la t0, disk_initialized
    lw t1, 0(t0)
    beqz t1, dws_error
    li t0, TOTAL_SECTORS
    bgeu s0, t0, dws_error
    call disk_wait
    bnez a0, dws_error
    li t0, DISK_SECTOR
    sw s0, 0(t0)
    li t0, DISK_BUFFER
    sw s1, 0(t0)
    li t0, DISK_COMMAND
    li t1, CMD_WRITE
    sb t1, 0(t0)
    call disk_wait
    bnez a0, dws_error
    li a0, 0
    j dws_done
dws_error:
    li a0, -1
dws_done:
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

disk_wait:
    addi sp, sp, -16
    sd s0, 8(sp)
    li s0, 100000
dw_loop:
    beqz s0, dw_timeout
    addi s0, s0, -1
    li t0, DISK_STATUS
    lbu t1, 0(t0)
    li t2, STATUS_DONE
    beq t1, t2, dw_success
    li t2, STATUS_ERROR
    beq t1, t2, dw_error
    j dw_loop
dw_success:
    li a0, 0
    j dw_done
dw_timeout:
dw_error:
    li a0, -1
dw_done:
    ld s0, 8(sp)
    addi sp, sp, 16
    ret

# Simple File System (SFS) - Core Structures

.section .data
.equ FS_MAGIC, 0x53465300
.equ SECTOR_SIZE, 512
.equ INODE_SIZE, 32
.equ DIRENTRY_SIZE, 32
.equ MAX_INODES, 256
.equ MAX_NAME_LEN, 28
.equ SUPERBLOCK_SECTOR, 0
.equ INODE_TABLE_START, 1
.equ BITMAP_START, 17
.equ DATA_START, 33
.equ INODE_FREE, 0
.equ INODE_FILE, 1
.equ INODE_DIR, 2

.globl fs_initialized
fs_initialized: .word 0

.align 4
superblock_cache:
    .word 0, 0, 0, 0, 0
    .space 492

.align 4
.globl sector_buffer
sector_buffer: .space 512

.section .text
.globl fs_init, fs_format, fs_alloc_inode, fs_free_inode, fs_read_inode, fs_write_inode, fs_alloc_block, fs_free_block
.extern disk_init, disk_read_sector, disk_write_sector

fs_init:
    addi sp, sp, -16
    sd ra, 8(sp)
    call disk_init
    li a0, SUPERBLOCK_SECTOR
    la a1, superblock_cache
    call disk_read_sector
    bnez a0, fsi_error
    la t0, superblock_cache
    lw t1, 0(t0)
    li t2, FS_MAGIC
    bne t1, t2, fsi_error
    la t0, fs_initialized
    li t1, 1
    sw t1, 0(t0)
    li a0, 0
    j fsi_done
fsi_error:
    li a0, -1
fsi_done:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

fs_format:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    la t0, superblock_cache
    li t1, FS_MAGIC
    sw t1, 0(t0)
    li t1, 65536
    sw t1, 4(t0)
    addi t1, t1, -33
    sw t1, 8(t0)
    li t1, MAX_INODES
    sw t1, 12(t0)
    addi t1, t1, -1
    sw t1, 16(t0)
    li a0, SUPERBLOCK_SECTOR
    la a1, superblock_cache
    call disk_write_sector
    bnez a0, fsf_error
    la t0, sector_buffer
    li t1, 512
fsf_clear_loop:
    beqz t1, fsf_clear_done
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    j fsf_clear_loop
fsf_clear_done:
    li s0, INODE_TABLE_START
    li s1, 16
fsf_inode_loop:
    beqz s1, fsf_inode_done
    mv a0, s0
    la a1, sector_buffer
    call disk_write_sector
    addi s0, s0, 1
    addi s1, s1, -1
    j fsf_inode_loop
fsf_inode_done:
    la t0, sector_buffer
    li t1, 0
    sw t1, 0(t0)
    li t1, INODE_DIR
    sw t1, 4(t0)
    li a0, INODE_TABLE_START
    la a1, sector_buffer
    call disk_write_sector
    bnez a0, fsf_error
    la t0, fs_initialized
    li t1, 1
    sw t1, 0(t0)
    li a0, 0
    j fsf_done
fsf_error:
    li a0, -1
fsf_done:
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

fs_alloc_inode:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    li s0, 0
    li s1, MAX_INODES
fai_loop:
    bge s0, s1, fai_error
    mv a0, s0
    call fs_read_inode
    bnez a0, fai_next
    la t0, sector_buffer
    lw t1, 4(t0)
    beqz t1, fai_found
fai_next:
    addi s0, s0, 1
    j fai_loop
fai_found:
    mv a0, s0
    j fai_done
fai_error:
    li a0, -1
fai_done:
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

fs_free_inode:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
    call fs_read_inode
    bnez a0, ffi_done
    la t0, sector_buffer
    sw zero, 4(t0)
    mv a0, s0
    call fs_write_inode
ffi_done:
    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

fs_read_inode:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
    li t0, INODE_TABLE_START
    srli t1, s0, 4
    add t0, t0, t1
    mv a0, t0
    la a1, sector_buffer
    call disk_read_sector
    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

fs_write_inode:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
    li t0, INODE_TABLE_START
    srli t1, s0, 4
    add t0, t0, t1
    mv a0, t0
    la a1, sector_buffer
    call disk_write_sector
    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

fs_alloc_block:
    li a0, DATA_START
    ret

fs_free_block:
    ret

# String Utilities for Leenux OS

.section .text
.globl strlen, strcmp, strcpy, strncpy, get_first_word

strlen:
    mv t0, a0
    li t1, 0
strlen_loop:
    lbu t2, 0(t0)
    beq t2, zero, strlen_done
    addi t0, t0, 1
    addi t1, t1, 1
    j strlen_loop
strlen_done:
    mv a0, t1
    ret

strcmp:
    mv t0, a0
    mv t1, a1
strcmp_loop:
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    bne t2, t3, strcmp_diff
    beq t2, zero, strcmp_equal
    addi t0, t0, 1
    addi t1, t1, 1
    j strcmp_loop
strcmp_equal:
    li a0, 0
    ret
strcmp_diff:
    sub a0, t2, t3
    ret

strcpy:
    mv t0, a0
    mv t1, a0
    mv t2, a1
strcpy_loop:
    lbu t3, 0(t2)
    sb t3, 0(t1)
    beq t3, zero, strcpy_done
    addi t1, t1, 1
    addi t2, t2, 1
    j strcpy_loop
strcpy_done:
    mv a0, t0
    ret

strncpy:
    mv t0, a0
    mv t1, a0
    mv t2, a1
    mv t3, a2
strncpy_loop:
    beq t3, zero, strncpy_done
    lbu t4, 0(t2)
    sb t4, 0(t1)
    beq t4, zero, strncpy_done
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, -1
    j strncpy_loop
strncpy_done:
    mv a0, t0
    ret

get_first_word:
    mv t0, a0
    li t1, 0
gfw_loop:
    lbu t2, 0(t0)
    beq t2, zero, gfw_done
    li t3, 0x20
    beq t2, t3, gfw_found_space
    li t3, 0x09
    beq t2, t3, gfw_found_space
    addi t0, t0, 1
    addi t1, t1, 1
    j gfw_loop
gfw_found_space:
    sb zero, 0(t0)
gfw_done:
    mv a1, t1
    ret

# Simple Screen Driver for Leenux
# Implements basic character drawing

.section .text
.globl draw_char
.globl draw_string

# External font data
.extern font_5x8
.extern font_5x8_width
.extern font_5x8_height

#=============================================================================
# draw_char: Draw a character
# Arguments: 
#   a0 = char (ASCII)
#   a1 = x coordinate
#   a2 = y coordinate
#   a3 = color (0x00RRGGBB)
#=============================================================================
draw_char:
    addi sp, sp, -48
    sd s0, 40(sp)
    sd s1, 32(sp)
    sd s2, 24(sp)
    sd s3, 16(sp)
    sd ra, 8(sp)
    
    # Check ASCII range (32-126)
    li t0, 32
    blt a0, t0, draw_char_done
    li t0, 126
    bgt a0, t0, draw_char_done
    
    # Calculate font offset
    addi s0, a0, -32
    slli s0, s0, 3
    la t0, font_5x8
    add s0, s0, t0
    
    mv s1, a1
    mv s2, a2
    mv s3, a3
    
    # Base: 0x10003000
    lui t0, 0x10003
    li t1, 1024
    mul t1, s2, t1
    add t1, t1, s1
    slli t1, t1, 2
    add t0, t0, t1
    
    li t1, 0
    li t2, 8
    
draw_row_loop:
    bge t1, t2, draw_char_done
    lbu t3, 0(s0)
    addi s0, s0, 1
    
    li t4, 0
    li t5, 5
    mv t6, t0
    
draw_col_loop:
    bge t4, t5, draw_row_done
    li a4, 4
    sub a4, a4, t4
    srl a5, t3, a4
    andi a5, a5, 1
    beqz a5, pixel_skip
    sw s3, 0(t6)
    
pixel_skip:
    addi t6, t6, 4
    addi t4, t4, 1
    j draw_col_loop
    
draw_row_done:
    li a4, 4096
    add t0, t0, a4
    addi t1, t1, 1
    j draw_row_loop
    
draw_char_done:
    ld ra, 8(sp)
    ld s3, 16(sp)
    ld s2, 24(sp)
    ld s1, 32(sp)
    ld s0, 40(sp)
    addi sp, sp, 48
    ret

#=============================================================================
# draw_string: Draw a null-terminated string
# Arguments:
#   a0 = string pointer
#   a1 = x, a2 = y, a3 = color
#=============================================================================
draw_string:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    
draw_string_loop:
    lbu a0, 0(s0)
    beqz a0, draw_string_done
    mv a1, s1
    mv a2, s2
    mv a3, s3
    call draw_char
    addi s0, s0, 1
    addi s1, s1, 6
    j draw_string_loop
    
draw_string_done:
    ld s3, 8(sp)
    ld s2, 16(sp)
    ld s1, 24(sp)
    ld s0, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

# 5x8 Bitmap Font
# Each character is 8 bytes (one byte per row)
# Each byte represents 5 pixels: bits 4-0 (MSB=left, LSB=right)
# Character set: ASCII 32-126 (space through tilde)

.section .data
.globl font_5x8
.globl font_5x8_width
.globl font_5x8_height

font_5x8_width:  .word 5
font_5x8_height: .word 8

font_5x8:
    # ASCII 32: Space
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    
    # ASCII 33: !
    .byte 0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04, 0x00
    
    # ASCII 34: "
    .byte 0x0A, 0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00
    
    # ASCII 35: #
    .byte 0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A, 0x00
    
    # ASCII 36: $
    .byte 0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04, 0x00
    
    # ASCII 37: %
    .byte 0x18, 0x19, 0x02, 0x04, 0x08, 0x13, 0x03, 0x00
    
    # ASCII 38: &
    .byte 0x0C, 0x12, 0x14, 0x08, 0x15, 0x12, 0x0D, 0x00
    
    # ASCII 39: '
    .byte 0x04, 0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00
    
    # ASCII 40: (
    .byte 0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02, 0x00
    
    # ASCII 41: )
    .byte 0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08, 0x00
    
    # ASCII 42: *
    .byte 0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00, 0x00
    
    # ASCII 43: +
    .byte 0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00, 0x00
    
    # ASCII 44: ,
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x04, 0x08
    
    # ASCII 45: -
    .byte 0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00, 0x00
    
    # ASCII 46: .
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00
    
    # ASCII 47: /
    .byte 0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00, 0x00
    
    # ASCII 48-57: Digits 0-9
    # 0
    .byte 0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E, 0x00
    # 1
    .byte 0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00
    # 2
    .byte 0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F, 0x00
    # 3
    .byte 0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E, 0x00
    # 4
    .byte 0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02, 0x00
    # 5
    .byte 0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E, 0x00
    # 6
    .byte 0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E, 0x00
    # 7
    .byte 0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08, 0x00
    # 8
    .byte 0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E, 0x00
    # 9
    .byte 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C, 0x00
    
    # ASCII 58-64: : ; < = > ? @
    # :
    .byte 0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x00, 0x00
    # ;
    .byte 0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x04, 0x08
    # <
    .byte 0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02, 0x00
    # =
    .byte 0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00, 0x00
    # >
    .byte 0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08, 0x00
    # ?
    .byte 0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04, 0x00
    # @
    .byte 0x0E, 0x11, 0x01, 0x0D, 0x15, 0x15, 0x0E, 0x00
    
    # ASCII 65-90: Uppercase A-Z
    # A
    .byte 0x0E, 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x00
    # B
    .byte 0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E, 0x00
    # C
    .byte 0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E, 0x00
    # D
    .byte 0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C, 0x00
    # E
    .byte 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F, 0x00
    # F
    .byte 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10, 0x00
    # G
    .byte 0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F, 0x00
    # H
    .byte 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11, 0x00
    # I
    .byte 0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00
    # J
    .byte 0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C, 0x00
    # K
    .byte 0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11, 0x00
    # L
    .byte 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F, 0x00
    # M
    .byte 0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11, 0x00
    # N
    .byte 0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x00
    # O
    .byte 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00
    # P
    .byte 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10, 0x00
    # Q
    .byte 0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D, 0x00
    # R
    .byte 0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11, 0x00
    # S
    .byte 0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E, 0x00
    # T
    .byte 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x00
    # U
    .byte 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00
    # V
    .byte 0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04, 0x00
    # W
    .byte 0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A, 0x00
    # X
    .byte 0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11, 0x00
    # Y
    .byte 0x11, 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x00
    # Z
    .byte 0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F, 0x00
    
    # ASCII 91-96: [ \ ] ^ _ `
    # [
    .byte 0x0E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x0E, 0x00
    # \
    .byte 0x00, 0x10, 0x08, 0x04, 0x02, 0x01, 0x00, 0x00
    # ]
    .byte 0x0E, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E, 0x00
    # ^
    .byte 0x04, 0x0A, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00
    # _
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F, 0x00
    # `
    .byte 0x08, 0x04, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
    
    # ASCII 97-122: Lowercase a-z
    # a
    .byte 0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F, 0x00
    # b
    .byte 0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x1E, 0x00
    # c
    .byte 0x00, 0x00, 0x0E, 0x10, 0x10, 0x11, 0x0E, 0x00
    # d
    .byte 0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x0F, 0x00
    # e
    .byte 0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00
    # f
    .byte 0x06, 0x09, 0x08, 0x1C, 0x08, 0x08, 0x08, 0x00
    # g
    .byte 0x00, 0x0F, 0x11, 0x11, 0x0F, 0x01, 0x0E, 0x00
    # h
    .byte 0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x11, 0x00
    # i
    .byte 0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x0E, 0x00
    # j
    .byte 0x02, 0x00, 0x06, 0x02, 0x02, 0x12, 0x0C, 0x00
    # k
    .byte 0x10, 0x10, 0x12, 0x14, 0x18, 0x14, 0x12, 0x00
    # l
    .byte 0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00
    # m
    .byte 0x00, 0x00, 0x1A, 0x15, 0x15, 0x11, 0x11, 0x00
    # n
    .byte 0x00, 0x00, 0x16, 0x19, 0x11, 0x11, 0x11, 0x00
    # o
    .byte 0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E, 0x00
    # p
    .byte 0x00, 0x00, 0x1E, 0x11, 0x1E, 0x10, 0x10, 0x00
    # q
    .byte 0x00, 0x00, 0x0D, 0x13, 0x0F, 0x01, 0x01, 0x00
    # r
    .byte 0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10, 0x00
    # s
    .byte 0x00, 0x00, 0x0E, 0x10, 0x0E, 0x01, 0x1E, 0x00
    # t
    .byte 0x08, 0x08, 0x1C, 0x08, 0x08, 0x09, 0x06, 0x00
    # u
    .byte 0x00, 0x00, 0x11, 0x11, 0x11, 0x13, 0x0D, 0x00
    # v
    .byte 0x00, 0x00, 0x11, 0x11, 0x11, 0x0A, 0x04, 0x00
    # w
    .byte 0x00, 0x00, 0x11, 0x11, 0x15, 0x15, 0x0A, 0x00
    # x
    .byte 0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x00
    # y
    .byte 0x00, 0x00, 0x11, 0x11, 0x0F, 0x01, 0x0E, 0x00
    # z
    .byte 0x00, 0x00, 0x1F, 0x02, 0x04, 0x08, 0x1F, 0x00
    
    # ASCII 123-126: { | } ~
    # {
    .byte 0x02, 0x04, 0x04, 0x08, 0x04, 0x04, 0x02, 0x00
    # |
    .byte 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x00
    # }
    .byte 0x08, 0x04, 0x04, 0x02, 0x04, 0x04, 0x08, 0x00
    # ~
    .byte 0x00, 0x00, 0x00, 0x0C, 0x12, 0x00, 0x00, 0x00

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

# Keyboard Driver for Leenux OS

.section .data
.globl input_buffer, input_head, input_tail
input_buffer: .space 256
input_head: .word 0
input_tail: .word 0
.equ KB_BASE, 0x14000000
.equ KB_DATA, 0x14000000
.equ KB_STATUS, 0x14000004

.section .text
.globl keyboard_poll, keyboard_getchar, keyboard_available

keyboard_poll:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    lui s0, 0x14000
    lw t0, 4(s0)
    andi t0, t0, 1
    beq t0, zero, poll_no_data
    lw t1, 0(s0)
    la t2, input_buffer
    la t3, input_head
    lw t4, 0(t3)
    andi t5, t4, 0xFF
    add t5, t2, t5
    sb t1, 0(t5)
    addi t4, t4, 1
    andi t4, t4, 0xFF
    sw t4, 0(t3)
    li a0, 1
    j poll_done
poll_no_data:
    li a0, 0
poll_done:
    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

keyboard_getchar:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)
    lw t3, 0(t1)
    beq t2, t3, getchar_empty
    la t4, input_buffer
    andi t5, t2, 0xFF
    add t5, t4, t5
    lbu a0, 0(t5)
    addi t2, t2, 1
    andi t2, t2, 0xFF
    sw t2, 0(t0)
    ret
getchar_empty:
    li a0, 0
    ret

keyboard_available:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)
    lw t3, 0(t1)
    sub a0, t3, t2
    andi a0, a0, 0xFF
    ret

