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
