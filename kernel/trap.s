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
