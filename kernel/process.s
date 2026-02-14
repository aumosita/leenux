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
