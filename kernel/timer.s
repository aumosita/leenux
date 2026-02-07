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
