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
