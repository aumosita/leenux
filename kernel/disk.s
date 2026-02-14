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
