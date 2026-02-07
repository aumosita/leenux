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
