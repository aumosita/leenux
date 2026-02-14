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
