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
