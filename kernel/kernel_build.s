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
    sw ra, 12(sp)
    
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
    # Only check prefix for touch (simplification for now)
    # TODO: Proper argument parsing
    # For now, precise match "touch test" is hard in pure asm without tokenizer logic reused
    # We will just accept "touch" and create a default file "newfile.txt" for demo
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
    # sector_buffer is utilized by fs_read_inode
    # BUT fs_read_inode reads to sector_buffer
    # Inode structure:
    # 0: size
    # 4: type
    # 8-31: name (24 bytes)
    
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
    # TODO: Integer printing needed. For now just spaces
    # call print_int 
    # Placeholder:
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
    # Create "new.txt"
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
    
    # Name "new.txt"
    li t1, 0x6E       # n
    sb t1, 8(t0)
    li t1, 0x65       # e
    sb t1, 9(t0)
    li t1, 0x77       # w
    sb t1, 10(t0)
    li t1, 0
    sb t1, 11(t0)
    
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
    # DEBUG: Print 'S'
    li a0, 83
    call term_putchar
    
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
    # This runs in its own context
    # Loop and print a character every now and then
    
    li s1, 0  # Counter

bg_loop:
    # Small delay loop to simulate work
    li t0, 500000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    
    # Print a dot to show we are alive
    li a0, 46 # '.'
    # call term_putchar  <-- OLD (Direct Call)
    call u_putchar     # <-- NEW (Syscall)
    
    # Yield back to shell
    # call yield         <-- OLD (Direct Call)
    call u_yield       # <-- NEW (Syscall)
    
    j bg_loop

#=============================================================================
# User Mode Syscall Wrappers
#=============================================================================
u_yield:
    li a7, 0        # SYS_YIELD
    ecall
    ret

u_putchar:
    # a0 already has char
    li a7, 1        # SYS_PUTCHAR
    ecall
    ret

exec_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# Helpers
#=============================================================================
print_string:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
ps_loop:
    lbu a0, 0(s0)
    beqz a0, ps_done
    call term_putchar
    addi s0, s0, 1
    j ps_loop
ps_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4

msg_welcome: .asciz "\nWelcome to Leenux Shell (Preemptive)!\nType 'help' for commands.\n"
msg_unknown: .asciz "Unknown command: "
msg_help: .asciz "Commands: help, ls, touch, format, clear, spawn\n"
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

# Variables
.align 4
cmd_length: .word 0
command_line: .space 128
sector_buffer: .space 512

.align 4

.section .data
.align 4

msg_welcome: .asciz "\nWelcome to Leenux Shell (Preemptive)!\nType 'help' for commands.\n"
msg_unknown: .asciz "Unknown command: "
msg_help: .asciz "Commands: help, ls, touch, format, clear, spawn\n"
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

# Variables
.align 4
cmd_length: .word 0
command_line: .space 128
sector_buffer: .space 512

.align 4
# Process Management for Leenux OS
# Implements PCB, Scheduler, and Context Switching

.section .data
.globl proc_table
.globl current_proc
.globl proc_count

# Constants
.equ MAX_PROCESSES, 4
.equ STACK_SIZE, 1024       # 1KB stack per process
.equ PROC_STATE_UNUSED, 0
.equ PROC_STATE_READY, 1
.equ PROC_STATE_RUNNING, 2

# Process Control Block (PCB) Structure (Aligned to 32 bytes for simplicity)
# Offset 0: PID (4 bytes)
# Offset 4: State (4 bytes)
# Offset 8: SP (8 bytes)
# Offset 16: Stack Base (8 bytes)
# Total: 24 bytes (padded to 32)
.equ PCB_SIZE, 32
.equ PCB_OFFSET_PID, 0
.equ PCB_OFFSET_STATE, 4
.equ PCB_OFFSET_SP, 8
.equ PCB_OFFSET_STACK, 16

# storage
.align 3
proc_table: .space MAX_PROCESSES * PCB_SIZE
current_proc: .word -1      # PID of current process (-1 = none)
proc_count: .word 0

# Stacks for processes
.align 3
proc_stacks: .space MAX_PROCESSES * STACK_SIZE

.section .text
.globl proc_init
.globl proc_create
.globl schedule
.globl yield
.globl switch_context

#=============================================================================
# proc_init: Initialize process table
#=============================================================================
proc_init:
    addi sp, sp, -8
    sd ra, 0(sp)
    
    # Clear process table
    la t0, proc_table
    li t1, MAX_PROCESSES
    li t2, 0
    li t3, PROC_STATE_UNUSED
    
init_loop:
    sw t3, PCB_OFFSET_STATE(t0) # state = UNUSED
    addi t0, t0, PCB_SIZE
    addi t2, t2, 1
    blt t2, t1, init_loop
    
    # Set current proc to -1 initially, BUT for the boot process (Shell),
    # we need to register it as PID 0 so it can be scheduled back to.
    
    # Setup PID 0 (Shell/Boot)
    la t0, proc_table
    li t1, 0
    sw t1, PCB_OFFSET_PID(t0)      # PID = 0
    li t2, PROC_STATE_RUNNING
    sw t2, PCB_OFFSET_STATE(t0)    # State = RUNNING
    
    # We don't set SP yet, yield will save it.
    # We assume Boot uses the initial stack which is separate from proc_stacks,
    # or we can leave stack_base 0. switch_context purely uses SP.
    
    # Set current proc to 0
    la t0, current_proc
    sw t1, 0(t0)
    
    # Set count to 1
    la t0, proc_count
    li t1, 1
    sw t1, 0(t0)
    
    ld ra, 0(sp)
    addi sp, sp, 8
    ret

#=============================================================================
# proc_create: Create a new process
# Input: a0 = entry point address (function pointer)
# Returns: a0 = PID or -1 if full
#=============================================================================
proc_create:
    addi sp, sp, -16
    sd ra, 0(sp)
    sd s0, 8(sp)
    
    mv s0, a0  # Save entry point
    
    # Find free slot
    la t0, proc_table
    li t1, 0        # PID counter
    li t2, MAX_PROCESSES
    
find_free:
    lw t3, PCB_OFFSET_STATE(t0)
    li t4, PROC_STATE_UNUSED
    beq t3, t4, found_slot
    
    addi t0, t0, PCB_SIZE
    addi t1, t1, 1
    blt t1, t2, find_free
    
    # No free slot
    li a0, -1
    j proc_create_end

found_slot:
    # Initialize PCB
    sw t1, PCB_OFFSET_PID(t0)           # Set PID
    li t3, PROC_STATE_READY
    sw t3, PCB_OFFSET_STATE(t0)         # Set STATE = READY
    
    # Calculate Stack Pointer
    # SP = proc_stacks + (PID + 1) * STACK_SIZE
    la t4, proc_stacks
    addi t5, t1, 1
    li t6, STACK_SIZE
    mul t5, t5, t6
    add t4, t4, t5   # t4 = Top of stack
    
    sw t4, PCB_OFFSET_STACK(t0)        # Save stack base (top)
    
    # Setup initial stack frame for the new process & context switch
    # When we switch TO this process, we load registers from its stack.
    # Context switch restores: s0-s11, ra.
    # So we must push initial RA and S0-S11 to this new stack.
    
    # Stack layout for switch_context:
    # -8:  ra (entry point)
    # -16: s0
    # ...
    # -104: s11
    
    # Adjust mock SP
    addi t4, t4, -104   # Reserve space for 13 registers (ra + s0-s11) * 8 bytes
    sd t4, PCB_OFFSET_SP(t0) # Save SP to PCB
    
    # Write Entry Point to RA slot in the mock stack
    # RA is at offset 96 from current SP (since we did sp-104, 13th slot is top)
    # wait, pop logic:
    # ld s11, 0(sp)
    # ...
    # ld ra,  96(sp)
    # So we write entry point to 96(sp)
    # Write Entry Point to s0 slot (so it's restored into s0)
    # s0 is at offset 0 from top-of-frame (since we did sp-104)
    # Stack layout: 
    # 0(sp) = s0
    # ...
    # 96(sp) = ra
    sd s0, 0(t4)
    
    # Write Trampoline Address to RA slot
    la t6, k_to_user
    sd t6, 96(t4)
    
    # Increment proc_count
    la t5, proc_count
    lw t6, 0(t5)
    addi t6, t6, 1
    sw t6, 0(t5)
    
    mv a0, t1       # Return PID

proc_create_end:
    ld s0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# schedule: Pick next process and switch
#=============================================================================
schedule:
    # Save RA to stack because switch_context behaves like a call but returns elsewhere
    addi sp, sp, -8
    sd ra, 0(sp)
    
    # 1. Get current process ID
    la t0, current_proc
    lw t1, 0(t0)   # t1 = Current PID
    
    # 2. Find next READY process (Round Robin)
    # Start search from (current_pid + 1)
    addi t2, t1, 1  # Next PID candidate
    li t3, MAX_PROCESSES
    rem t2, t2, t3  # Wrap around
    
    mv t4, t2       # Scan start index
    li t5, 0        # Loop counter
    
scan_loop:
    # Check if we scanned all
    bge t5, t3, no_switch
    
    # Get PCB address: proc_table + candidate * PCB_SIZE
    la t6, proc_table
    li a1, PCB_SIZE
    mul a2, t2, a1
    add t6, t6, a2  # t6 = PCB pointer
    
    # Check state
    lw a3, PCB_OFFSET_STATE(t6)
    li a4, PROC_STATE_READY
    beq a3, a4, switch_to
    li a4, PROC_STATE_RUNNING
    # If it's already RUNNING (should rely on state, but here simple RR)
    # If we find RUNNING other than current? Should not happen in single core coop
    
    # Next candidate
    addi t2, t2, 1
    rem t2, t2, t3
    addi t5, t5, 1
    j scan_loop

no_switch:
    # No other tasks ready, just return (continue current)
    ld ra, 0(sp)
    addi sp, sp, 8
    ret

switch_to:
    # t1 = Old PID
    # t2 = New PID
    # t6 = New PCB Pointer
    
    # Update current_proc
    la a0, current_proc
    sw t2, 0(a0)
    
    # Update states
    # Set New Task to RUNNING
    li a1, PROC_STATE_RUNNING
    sw a1, PCB_OFFSET_STATE(t6)
    
    # Handle Old Task (if valid)
    li a2, -1
    beq t1, a2, first_run # If no current task, just jump to new
    
    # Get Old PCB
    la a3, proc_table
    li a4, PCB_SIZE
    mul a5, t1, a4
    add a3, a3, a5  # a3 = Old PCB
    
    # Set Old Task to READY
    li a6, PROC_STATE_READY
    sw a6, PCB_OFFSET_STATE(a3)
    
    # Perform Context Switch
    # a0 = &Old_PCB.SP (pointer to where to save old SP)
    # a1 = New_PCB.SP (value of new SP)
    
    addi a0, a3, PCB_OFFSET_SP # Address of SP field in Old PCB
    ld a1, PCB_OFFSET_SP(t6)   # Value of SP field in New PCB
    
    call switch_context
    
    # Returned from switch_context (back in execution)
    ld ra, 0(sp)
    addi sp, sp, 8
    ret

first_run:
    # Special case: First schedule ever
    # Just load new SP and restore
    ld sp, PCB_OFFSET_SP(t6)
    # We need to jump to restore part of switch_context manually
    # or just call a helper.
    # For simplicity, we can fake a call to switch_context with dummy old ptr
    # But better to just load SP and jump to a restore_context label
    j restore_context

#=============================================================================
# yield: Voluntary CPU surrender
#=============================================================================
yield:
    j schedule

#=============================================================================
# switch_context: Low-level Context Switcher
# a0 = pointer to save old SP
# a1 = new SP value
#=============================================================================
switch_context:
    # Save Callee-Saved Registers to current stack
    addi sp, sp, -104
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
    
    # Save old SP to PCB
    sd sp, 0(a0)

restore_context:
    # Load new SP
    mv sp, a1
    
    # Restore Callee-Saved Registers from new stack
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
    
    addi sp, sp, 104
    ret

#=============================================================================
# k_to_user: Trampoline to switch to User Mode
# Expects: s0 = User Entry Point
#=============================================================================
k_to_user:
    # 1. Set MEPC to the user entry point
    csrw mepc, s0
    
    # 2. Configure MSTATUS
    # Clear MPP (bits 11-12) to 00 (User Mode)
    # Set MPIE (bit 7) to 1 (Enable Interrupts in U-Mode)
    
    csrr t0, mstatus
    li t1, 0x1800       # Bits 11-12 (MPP)
    csrc mstatus, t1    # Clear MPP (sets to 00 = User Mode)
    
    li t1, 0x80         # MPIE bit
    csrs mstatus, t1    # Set MPIE (Enable Interrupts in U-Mode)
    
    # 3. Enter User Mode
    mret
# Trap Handler for Leenux OS
# Handles Interrupts and Exceptions

.section .text
.globl trap_init
.globl trap_vector

#=============================================================================
# trap_init: Setup mtvec
#=============================================================================
trap_init:
    la t0, trap_vector
    csrw mtvec, t0
    ret

#=============================================================================
# trap_vector: Main Entry Point for Traps
#=============================================================================
.align 4
trap_vector:
    # 1. Save Context
    # We need to save ALL registers because an interrupt can happen ANYWHERE.
    # For now, we reuse the current stack.
    # Ideally, we should switch to a kernel trap stack.
    # But since we are already in Machine Mode (No User Mode yet), SP is trusted.
    
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
    
    # 2. Check Cause
    csrr t0, mcause
    
    # Check if Interrupt (Bit 63)
    li t1, 0x8000000000000000
    and t2, t0, t1
    beqz t2, handle_exception
    
    # Is Interrupt
    # Mask out bit 63
    not t1, t1
    and t0, t0, t1
    
    # DEBUG: Print 'I' for Interrupt
    li a0, 73
    call term_putchar
    
    # Check for Machine Timer Interrupt (Code 7)
    li t1, 7
    beq t0, t1, handle_timer
    
    # DEBUG: Print 'U' for Unknown Interrupt
    li a0, 85
    call term_putchar
    
    # Unknown Interrupt
    j trap_exit

handle_timer:
    call timer_handler
    j trap_exit

handle_exception:
    # Check for Ecall from U-mode (Cause 8)
    li t1, 8
    beq t0, t1, handle_syscall
    
    # DEBUG: Print 'E' for Exception
    li a0, 69
    call term_putchar
    
    # Infinite loop on other exceptions
    j handle_exception

handle_syscall:
    # 1. Advance MEPC by 4 (skip ecall instruction)
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    
    # 2. Dispatch based on a7 (Syscall Number)
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
    # a0 contains char
    call term_putchar
    j trap_exit
    
sys_exit:
    # TODO: Implement exit
    j sys_yield

trap_exit:
    # 3. Restore Context
    ld ra, 0(sp)
    # sp is restored at the end
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
    sd s4, 152(sp)
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
# Maps to emulator's CLINT at 0x10001000

.section .data
.align 3
# CLINT Memory Map (Custom TimerDevice)
# 0x00: Current Cycle (MTIME)
# 0x08: Alarm Cycle (MTIMECMP)
# 0x10: Control Register (Bit 0: Enable)
.equ CLINT_BASE, 0x10001000
.equ CLINT_MTIME,    0x00
.equ CLINT_MTIMECMP, 0x08
.equ CLINT_CTRL,     0x10

# Timer Interval (Cycles)
.equ TIMER_INTERVAL, 100000

.section .text
.globl timer_init
.globl timer_handler

#=============================================================================
# timer_init: Initialize Timer
#=============================================================================
timer_init:
    addi sp, sp, -16
    sd ra, 0(sp)
    sd s0, 8(sp)

    # 1. Read current mtime
    li t0, CLINT_BASE
    # li t1, CLINT_MTIME (0)
    ld t2, CLINT_MTIME(t0)    # t2 = current time
    
    # 2. Add interval
    li t3, TIMER_INTERVAL
    add t2, t2, t3
    
    # 3. Write to mtimecmp
    sd t2, CLINT_MTIMECMP(t0)
    
    # 4. Enable Timer Device (Write 1 to Control)
    li t3, 1
    sb t3, CLINT_CTRL(t0)
    
    # 5. Enable Machine Timer Interrupt (MIE bit 7)
    li t0, 0x80     # bit 7 (MTIE)
    csrs mie, t0    # Set MTIE bit in mie register
    
    ld s0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# timer_handler: Handle Timer Interrupt
#=============================================================================
timer_handler:
    addi sp, sp, -16
    sd ra, 0(sp)
    sd s0, 8(sp)
    
    # DEBUG: Print 'T'
    li a0, 84
    call term_putchar
    
    # 1. Clear Alarm (Write 2 to Control, or just update cmp?)
    # TimerDevice says: "bit 1 쓰기로 알람 클리어" (Write bit 1 to clear)
    li t0, CLINT_BASE
    li t1, 3        # Bit 0 (Enable) | Bit 1 (Clear Trigger)
    sb t1, CLINT_CTRL(t0)
    
    # 2. Schedule next interrupt
    # Read old cmp
    ld t2, CLINT_MTIMECMP(t0)
    
    # Add interval
    li t3, TIMER_INTERVAL
    add t2, t2, t3
    
    # Write back
    sd t2, CLINT_MTIMECMP(t0)
    
    # 3. Call Scheduler
    call schedule
    
    ld s0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 16
    ret
# Disk Driver - MMIO Block Device
# 512-byte sector I/O for Leenux OS

.section .data

# Disk MMIO registers (base: 0x15000000)
.equ DISK_BASE, 0x15000000
.equ DISK_SECTOR, 0x15000000      # 4 bytes: sector number
.equ DISK_BUFFER, 0x15000004      # 4 bytes: buffer address
.equ DISK_COMMAND, 0x15000008     # 1 byte: command
.equ DISK_STATUS, 0x1500000C      # 1 byte: status

# Commands
.equ CMD_READ, 0x01
.equ CMD_WRITE, 0x02

# Status
.equ STATUS_IDLE, 0x00
.equ STATUS_BUSY, 0x01
.equ STATUS_DONE, 0x02
.equ STATUS_ERROR, 0xFF

# Disk geometry
.equ SECTOR_SIZE, 512
.equ TOTAL_SECTORS, 65536         # 32 MB disk

.globl disk_initialized
disk_initialized: .word 0

.section .text
.globl disk_init
.globl disk_read_sector
.globl disk_write_sector
.globl disk_wait

#=============================================================================
# disk_init: Initialize disk controller
#=============================================================================
disk_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Check if disk is present by reading status
    li t0, DISK_STATUS
    lbu t1, 0(t0)
    
    # Any status means disk is there
    # (In real hardware, we'd check device ID)
    
    # Mark as initialized
    la t0, disk_initialized
    li t1, 1
    sw t1, 0(t0)
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# disk_read_sector: Read one sector from disk
#
# Arguments:
#   a0 = sector number
#   a1 = buffer address (must be 512 bytes)
# Returns:
#   a0 = 0 on success, -1 on error
#=============================================================================
disk_read_sector:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    mv s0, a0                # Save sector
    mv s1, a1                # Save buffer
    
    # Check if initialized
    la t0, disk_initialized
    lw t1, 0(t0)
    beqz t1, drs_error
    
    # Check sector bounds
    li t0, TOTAL_SECTORS
    bgeu s0, t0, drs_error
    
    # Wait for disk to be idle
    call disk_wait
    bnez a0, drs_error
    
    # Set sector number
    li t0, DISK_SECTOR
    sw s0, 0(t0)
    
    # Set buffer address
    li t0, DISK_BUFFER
    sw s1, 0(t0)
    
    # Issue read command
    li t0, DISK_COMMAND
    li t1, CMD_READ
    sb t1, 0(t0)
    
    # Wait for completion
    call disk_wait
    bnez a0, drs_error
    
    # Success
    li a0, 0
    j drs_done
    
drs_error:
    li a0, -1
    
drs_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# disk_write_sector: Write one sector to disk
#
# Arguments:
#   a0 = sector number
#   a1 = buffer address (512 bytes to write)
# Returns:
#   a0 = 0 on success, -1 on error
#=============================================================================
disk_write_sector:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    mv s0, a0                # Save sector
    mv s1, a1                # Save buffer
    
    # Check if initialized
    la t0, disk_initialized
    lw t1, 0(t0)
    beqz t1, dws_error
    
    # Check sector bounds
    li t0, TOTAL_SECTORS
    bgeu s0, t0, dws_error
    
    # Wait for disk to be idle
    call disk_wait
    bnez a0, dws_error
    
    # Set sector number
    li t0, DISK_SECTOR
    sw s0, 0(t0)
    
    # Set buffer address
    li t0, DISK_BUFFER
    sw s1, 0(t0)
    
    # Issue write command
    li t0, DISK_COMMAND
    li t1, CMD_WRITE
    sb t1, 0(t0)
    
    # Wait for completion
    call disk_wait
    bnez a0, dws_error
    
    # Success
    li a0, 0
    j dws_done
    
dws_error:
    li a0, -1
    
dws_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# disk_wait: Wait for disk operation to complete
#
# Returns:
#   a0 = 0 if successful (STATUS_DONE)
#   a0 = -1 if error (STATUS_ERROR or timeout)
#=============================================================================
disk_wait:
    addi sp, sp, -16
    sw s0, 12(sp)
    
    li s0, 100000            # Timeout counter
    
dw_loop:
    # Check timeout
    beqz s0, dw_timeout
    addi s0, s0, -1
    
    # Read status
    li t0, DISK_STATUS
    lbu t1, 0(t0)
    
    # Check if done
    li t2, STATUS_DONE
    beq t1, t2, dw_success
    
    # Check if error
    li t2, STATUS_ERROR
    beq t1, t2, dw_error
    
    # Still busy, keep waiting
    j dw_loop
    
dw_success:
    li a0, 0
    j dw_done
    
dw_timeout:
dw_error:
    li a0, -1
    
dw_done:
    lw s0, 12(sp)
    addi sp, sp, 16
    ret
# Simple File System (SFS) - Core Structures
# Superblock, inode, and block management

.section .data

# Filesystem constants
.equ FS_MAGIC, 0x53465300         # "SFS\0"
.equ SECTOR_SIZE, 512
.equ INODE_SIZE, 32
.equ DIRENTRY_SIZE, 32
.equ MAX_INODES, 256
.equ MAX_NAME_LEN, 28

# Sector layout
.equ SUPERBLOCK_SECTOR, 0
.equ INODE_TABLE_START, 1         # Sectors 1-16 (16*512/32 = 256 inodes)
.equ BITMAP_START, 17             # Sectors 17-32
.equ DATA_START, 33               # Sector 33+

# Inode types
.equ INODE_FREE, 0
.equ INODE_FILE, 1
.equ INODE_DIR, 2

.globl fs_initialized
fs_initialized: .word 0

# In-memory superblock cache
.align 4
superblock_cache:
    .word 0                       # magic
    .word 0                       # total_blocks
    .word 0                       # free_blocks  
    .word 0                       # total_inodes
    .word 0                       # free_inodes
    .space 492                    # reserved

# Temporary sector buffer
.align 4
.globl sector_buffer
sector_buffer: .space 512

.section .text
.globl fs_init
.globl fs_format
.globl fs_alloc_inode
.globl fs_free_inode
.globl fs_read_inode
.globl fs_write_inode
.globl fs_alloc_block
.globl fs_free_block

.extern disk_init
.extern disk_read_sector
.extern disk_write_sector

#=============================================================================
# fs_init: Initialize filesystem
# Reads superblock and validates magic number
#=============================================================================
fs_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Initialize disk first
    call disk_init
    
    # Read superblock (sector 0)
    li a0, SUPERBLOCK_SECTOR
    la a1, superblock_cache
    call disk_read_sector
    bnez a0, fsi_error
    
    # Verify magic
    la t0, superblock_cache
    lw t1, 0(t0)
    li t2, FS_MAGIC
    bne t1, t2, fsi_error
    
    # Mark initialized
    la t0, fs_initialized
    li t1, 1
    sw t1, 0(t0)
    
    li a0, 0
    j fsi_done
    
fsi_error:
    li a0, -1
    
fsi_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# fs_format: Format disk with SFS
# Creates superblock, clears inode table, creates root directory
#=============================================================================
fs_format:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Create superblock
    la t0, superblock_cache
    li t1, FS_MAGIC
    sw t1, 0(t0)                  # magic
    
    li t1, 65536
    sw t1, 4(t0)                  # total_blocks
    
    li t1, 65536
    addi t1, t1, -33              # Minus superblock, inodes, bitmap
    sw t1, 8(t0)                  # free_blocks
    
    li t1, MAX_INODES
    sw t1, 12(t0)                 # total_inodes
    
    li t1, MAX_INODES
    addi t1, t1, -1               # Reserve inode 0 for root
    sw t1, 16(t0)                 # free_inodes
    
    # Write superblock
    li a0, SUPERBLOCK_SECTOR
    la a1, superblock_cache
    call disk_write_sector
    bnez a0, fsf_error
    
    # Clear inode table (16 sectors)
    la t0, sector_buffer
    li t1, 512
fsf_clear_loop:
    beqz t1, fsf_clear_done
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    j fsf_clear_loop
fsf_clear_done:
    
    # Write empty inode sectors
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
    
    # Create root directory (inode 0)
    la t0, sector_buffer
    li t1, 0
    sw t1, 0(t0)                  # size = 0 (empty dir)
    li t1, INODE_DIR
    sw t1, 4(t0)                  # type = directory
    # Direct blocks initialized to 0 (no data blocks yet)
    
    # Write root inode
    li a0, INODE_TABLE_START
    la a1, sector_buffer
    call disk_write_sector
    bnez a0, fsf_error
    
    # Mark filesystem initialized
    la t0, fs_initialized
    li t1, 1
    sw t1, 0(t0)
    
    li a0, 0
    j fsf_done
    
fsf_error:
    li a0, -1
    
fsf_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# fs_alloc_inode: Allocate a new inode
#
# Returns: a0 = inode number (0-255) or -1 on error
#=============================================================================
fs_alloc_inode:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    # Search inode table for free entry
    li s0, 0                      # Current inode number
    li s1, MAX_INODES
    
fai_loop:
    bge s0, s1, fai_error
    
    # Read inode
    mv a0, s0
    call fs_read_inode
    bnez a0, fai_next
    
    # Check if free (type == 0)
    la t0, sector_buffer
    lw t1, 4(t0)
    beqz t1, fai_found
    
fai_next:
    addi s0, s0, 1
    j fai_loop
    
fai_found:
    # Return inode number
    mv a0, s0
    j fai_done
    
fai_error:
    li a0, -1
    
fai_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# fs_free_inode: Free an inode
#
# Arguments: a0 = inode number
#=============================================================================
fs_free_inode:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Read inode
    mv a0, s0
    call fs_read_inode
    bnez a0, ffi_done
    
    # Mark as free
    la t0, sector_buffer
    sw zero, 4(t0)                # type = 0 (free)
    
    # Write back
    mv a0, s0
    call fs_write_inode
    
ffi_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# fs_read_inode: Read inode into sector_buffer
#
# Arguments: a0 = inode number
# Returns: a0 = 0 on success, -1 on error
#=============================================================================
fs_read_inode:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Calculate sector: INODE_TABLE_START + (ino / 16)
    li t0, INODE_TABLE_START
    srli t1, s0, 4                # Divide by 16
    add t0, t0, t1
    
    # Read sector
    mv a0, t0
    la a1, sector_buffer
    call disk_read_sector
    
    # If successful, copy inode to start of buffer
    # (For simplicity, we keep the sector but could optimize)
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# fs_write_inode: Write inode from sector_buffer
#
# Arguments: a0 = inode number
# Returns: a0 = 0 on success, -1 on error
#=============================================================================
fs_write_inode:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Calculate sector
    li t0, INODE_TABLE_START
    srli t1, s0, 4
    add t0, t0, t1
    
    # Write sector
    mv a0, t0
    la a1, sector_buffer
    call disk_write_sector
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# fs_alloc_block: Allocate a data block
#
# Returns: a0 = block number or -1
#=============================================================================
fs_alloc_block:
    # TODO: Implement bitmap-based block allocation
    # For now, return a dummy block
    li a0, DATA_START
    ret

#=============================================================================
# fs_free_block: Free a data block
#
# Arguments: a0 = block number
#=============================================================================
fs_free_block:
    # TODO: Implement bitmap-based block freeing
    ret
# String Utilities for Leenux OS
# Common string operations

.section .text
.globl strlen
.globl strcmp
.globl strcpy
.globl strncpy
.globl get_first_word

#=============================================================================
# strlen: Calculate string length
#
# Arguments: a0 = string pointer
# Returns: a0 = length (not including null terminator)
#=============================================================================
strlen:
    mv t0, a0                # Save start
    li t1, 0                 # Counter
    
strlen_loop:
    lbu t2, 0(t0)
    beq t2, zero, strlen_done
    addi t0, t0, 1
    addi t1, t1, 1
    j strlen_loop
    
strlen_done:
    mv a0, t1
    ret

#=============================================================================
# strcmp: Compare two strings
#
# Arguments: a0 = string1, a1 = string2
# Returns: a0 = 0 if equal, non-zero if different
#=============================================================================
strcmp:
    mv t0, a0
    mv t1, a1
    
strcmp_loop:
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    
    # Check if different
    bne t2, t3, strcmp_diff
    
    # Check if end of string
    beq t2, zero, strcmp_equal
    
    # Continue
    addi t0, t0, 1
    addi t1, t1, 1
    j strcmp_loop
    
strcmp_equal:
    li a0, 0
    ret
    
strcmp_diff:
    sub a0, t2, t3
    ret

#=============================================================================
# strcpy: Copy string
#
# Arguments: a0 = dest, a1 = src
# Returns: a0 = dest
#=============================================================================
strcpy:
    mv t0, a0                # Save dest
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

#=============================================================================
# strncpy: Copy at most n characters
#
# Arguments: a0 = dest, a1 = src, a2 = n
# Returns: a0 = dest
#=============================================================================
strncpy:
    mv t0, a0                # Save dest
    mv t1, a0
    mv t2, a1
    mv t3, a2                # n
    
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

#=============================================================================
# get_first_word: Extract first word from string
#
# Arguments: a0 = source string
# Returns: a0 = pointer to first word (same as input, modified in place)
#          a1 = length of first word
#
# Note: This function finds the first word and null-terminates it
#       The string is modified in place (space becomes null)
#=============================================================================
get_first_word:
    mv t0, a0                # Current position
    li t1, 0                 # Word length
    
gfw_loop:
    lbu t2, 0(t0)
    
    # Check for end of string
    beq t2, zero, gfw_done
    
    # Check for space
    li t3, 0x20              # Space character
    beq t2, t3, gfw_found_space
    
    # Check for tab
    li t3, 0x09              # Tab character
    beq t2, t3, gfw_found_space
    
    # Regular character, continue
    addi t0, t0, 1
    addi t1, t1, 1
    j gfw_loop
    
gfw_found_space:
    # Null-terminate at space
    sb zero, 0(t0)
    j gfw_done
    
gfw_done:
    mv a1, t1                # Return length
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
    addi sp, sp, -32
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd s2, 16(sp)
    sd s3, 24(sp)
    
    # Check ASCII range (32-126)
    li t0, 32
    blt a0, t0, draw_char_done
    li t0, 126
    bgt a0, t0, draw_char_done
    
    # Calculate font offset
    # offset = (char - 32) * 8
    addi s0, a0, -32         # s0 = index
    slli s0, s0, 3           # s0 = index * 8
    la t0, font_5x8
    add s0, s0, t0           # s0 = pointer to char data
    
    # Variables
    mv s1, a1                # s1 = current x
    mv s2, a2                # s2 = current y
    mv s3, a3                # s3 = color
    
    # Framebuffer base: 0x10003000
    # Addr = Base + (y * 1024 + x) * 4
    lui t0, 0x10003
    
    # Calculate base pixel address for (x,y)
    li t1, 1024
    mul t1, s2, t1           # y * 1024
    add t1, t1, s1           # y * 1024 + x
    slli t1, t1, 2           # * 4
    add t0, t0, t1           # t0 = pixel address
    
    # Loop 8 rows
    li t1, 0                 # row counter
    li t2, 8                 # max rows
    
draw_row_loop:
    bge t1, t2, draw_char_done
    
    # Load font byte
    lb t3, 0(s0)
    addi s0, s0, 1           # Increment font pointer
    
    # Loop 5 cols
    # Value is in t3. bits 0-4.
    # MSB (bit 4) is left-most pixel?
    # font_5x8.s says: "bits 4-0 (MSB=left)"
    # Example: '!' is 0x04 (00100). Middle pixel set.
    
    li t4, 0                 # col counter
    li t5, 5                 # max cols
    mv t6, t0                # t6 = current line pixel ptr
    
draw_col_loop:
    bge t4, t5, draw_row_done
    
    # Check bit (4 - t4)
    li a4, 4
    sub a4, a4, t4           # Shift amount
    srl a5, t3, a4
    andi a5, a5, 1
    
    # If bit set, draw pixel
    beqz a5, pixel_skip
    sw s3, 0(t6)
    
pixel_skip:
    addi t6, t6, 4           # Next pixel
    addi t4, t4, 1
    j draw_col_loop
    
draw_row_done:
    # Move to next line in FB
    li a4, 4096              # 1024 * 4
    add t0, t0, a4
    addi t1, t1, 1
    j draw_row_loop
    
draw_char_done:
    ld s3, 24(sp)
    ld s2, 16(sp)
    ld s1, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# draw_string: Draw a null-terminated string
# Arguments:
#   a0 = string pointer
#   a1 = x
#   a2 = y
#   a3 = color
#=============================================================================
draw_string:
    addi sp, sp, -32
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)
    
    mv s0, a0
    mv s1, a1
    mv s2, a2
    # a3 is color (preserved)
    
draw_string_loop:
    lbu a0, 0(s0)            # Load char
    beqz a0, draw_string_done
    
    # Save a3? No, s registers preserved it? No, a3 is arg.
    # We should save color in s3?
    # But draw_char takes a3.
    # Let's save a3 in s3?
    # Stack space 32. 4 regs saved. OK.
    # Wait, simple: just pass a3.
    
    mv a1, s1
    mv a2, s2
    # a3 already set
    
    call draw_char
    
    # Advance
    addi s0, s0, 1           # Next char
    addi s1, s1, 6           # Next X (5 + 1 spacing)
    j draw_string_loop
    
draw_string_done:
    ld s2, 24(sp)
    ld s1, 16(sp)
    ld s0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 32
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
    call term_clear
    
    # Draw initial prompt
    call term_print_prompt
    
    ret

#=============================================================================
# term_clear: Clear entire screen
#=============================================================================
term_clear:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    
    # Fill screen with background color
    lui s0, 0x10003          # Framebuffer base
    lui s1, %hi(COLOR_BG)
    addi s1, s1, %lo(COLOR_BG)
    
    li t0, 786432            # 1024 * 768 pixels
    mv t1, s0
    
clear_loop:
    sw s1, 0(t1)
    addi t1, t1, 4
    addi t0, t0, -1
    bne t0, zero, clear_loop
    
    # Reset cursor
    la t0, cursor_x
    sw zero, 0(t0)
    la t0, cursor_y
    sw zero, 0(t0)
    
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# term_putchar: Display a character at cursor position
#
# Arguments: a0 = character
#=============================================================================
term_putchar:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                # Save character
    
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
    lui a3, %hi(COLOR_TEXT)
    addi a3, a3, %lo(COLOR_TEXT)
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
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# term_newline: Move cursor to next line
#=============================================================================
term_newline:
    addi sp, sp, -16
    sw ra, 12(sp)
    
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
    
    lw ra, 12(sp)
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
    sw ra, 12(sp)
    
    li a0, 32                # Space
    call term_putchar
    
    # Move cursor back again (putchar advanced it)
    la t0, cursor_x
    lw t1, 0(t0)
    addi t1, t1, -1
    sw t1, 0(t0)
    
    lw ra, 12(sp)
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
    sw ra, 12(sp)
    
    call term_clear
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# term_print_prompt: Display the command prompt
#=============================================================================
term_print_prompt:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Print "leenux> " in green
    la a2, prompt_string
    li a0, 0                 # x = 0
    la t0, cursor_y
    lw t1, 0(t0)
    li t2, 8
    mul a1, t1, t2
    li t2, TERM_MARGIN_Y
    add a1, a1, t2           # y = cursor_y * 8 + margin
    
    lui a3, %hi(COLOR_PROMPT)
    addi a3, a3, %lo(COLOR_PROMPT)
    call draw_string
    
    # Update cursor_x to after prompt
    la t0, cursor_x
    li t1, 8                 # "leenux> " = 8 chars
    sw t1, 0(t0)
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.section .rodata
prompt_string:
    .byte "leenux> ", 0
    .align 4
# Keyboard Driver for Leenux OS
# MMIO-based keyboard input with circular buffer

.section .data
.globl input_buffer
.globl input_head
.globl input_tail

# Circular input buffer (256 bytes)
input_buffer: .space 256
input_head: .word 0          # Write position
input_tail: .word 0          # Read position

# Keyboard MMIO addresses
.equ KB_BASE,    0x14000000
.equ KB_DATA,    0x14000000  # Data register
.equ KB_STATUS,  0x14000004  # Status register

.section .text
.globl keyboard_poll
.globl keyboard_getchar
.globl keyboard_available

#=============================================================================
# keyboard_poll: Check for keyboard input and add to buffer
#
# Called periodically (e.g., in main loop or timer interrupt)
# Returns: a0 = 1 if character was read, 0 otherwise
#=============================================================================
keyboard_poll:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0,  8(sp)
    
    # Check keyboard status (0x14000004)
    lui s0, 0x14000
    lw t0, 4(s0)             # Read status register
    
    # Check bit 0 (data ready)
    andi t0, t0, 1
    beq t0, zero, poll_no_data
    
    # Read character (0x14000000)
    lw t1, 0(s0)             # Read data register
    
    # Add to buffer
    la t2, input_buffer
    la t3, input_head
    lw t4, 0(t3)             # Load head
    
    # Calculate buffer position
    andi t5, t4, 0xFF        # Wrap to 256
    add t5, t2, t5           # buffer + head
    
    # Store character
    sb t1, 0(t5)
    
    # Increment head
    addi t4, t4, 1
    andi t4, t4, 0xFF        # Wrap around
    sw t4, 0(t3)
    
    # Return 1 (character read)
    li a0, 1
    j poll_done
    
poll_no_data:
    li a0, 0
    
poll_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# keyboard_getchar: Read one character from buffer
#
# Returns: a0 = character (0 if buffer empty)
#=============================================================================
keyboard_getchar:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)             # tail
    lw t3, 0(t1)             # head
    
    # Check if buffer empty
    beq t2, t3, getchar_empty
    
    # Read character
    la t4, input_buffer
    andi t5, t2, 0xFF
    add t5, t4, t5
    lbu a0, 0(t5)
    
    # Increment tail
    addi t2, t2, 1
    andi t2, t2, 0xFF
    sw t2, 0(t0)
    
    ret
    
getchar_empty:
    li a0, 0
    ret

#=============================================================================
# keyboard_available: Check if characters available in buffer
#
# Returns: a0 = number of characters in buffer
#=============================================================================
keyboard_available:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)             # tail
    lw t3, 0(t1)             # head
    
    # Calculate count (head - tail) & 0xFF
    sub a0, t3, t2
    andi a0, a0, 0xFF
    ret
