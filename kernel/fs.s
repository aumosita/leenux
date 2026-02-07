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
