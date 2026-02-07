# File Operations - open, read, write, close
# File descriptor management for Leenux OS

.section .data

# File descriptor table (16 entries)
.equ MAX_FDS, 16
.equ FD_SIZE, 16              # Each FD: inode(4), offset(4), flags(4), refcount(4)

.align 4
.globl fd_table
fd_table: .space 256          # 16 * 16 bytes

# Open flags
.equ O_RDONLY, 0x00
.equ O_WRONLY, 0x01
.equ O_RDWR, 0x02
.equ O_CREAT, 0x40

# Path buffer
.align 4
path_buffer: .space 256

.section .text
.globl file_open
.globl file_read
.globl file_write
.globl file_close
.globl file_init

.extern fs_read_inode
.extern fs_write_inode
.extern fs_alloc_inode
.extern sector_buffer
.extern disk_read_sector
.extern disk_write_sector

#=============================================================================
# file_init: Initialize file descriptor table
#=============================================================================
file_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Clear FD table
    la t0, fd_table
    li t1, 256
fi_loop:
    beqz t1, fi_done
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    j fi_loop
    
fi_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# file_open: Open a file
#
# Arguments:
#   a0 = path (null-terminated string)
#   a1 = flags (O_RDONLY, O_WRONLY, O_RDWR, O_CREAT)
# Returns:
#   a0 = file descriptor (0-15) or -1 on error
#=============================================================================
file_open:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                 # Save path
    mv s1, a1                 # Save flags
    
    # For now, simple implementation:
    # Just check if file is "/" (root)
    # Return a dummy FD
    
    # TODO: Implement path resolution
    # TODO: Search inode table
    # TODO: Allocate FD
    
    # Dummy: allocate FD 0 for root
    la t0, fd_table
    li t1, 0                  # inode 0 (root)
    sw t1, 0(t0)
    sw zero, 4(t0)            # offset = 0
    sw s1, 8(t0)              # flags
    li t1, 1
    sw t1, 12(t0)             # refcount = 1
    
    li a0, 0                  # Return FD 0
    
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# file_read: Read from file
#
# Arguments:
#   a0 = fd
#   a1 = buffer
#   a2 = count (bytes to read)
# Returns:
#   a0 = bytes read or -1 on error
#=============================================================================
file_read:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                 # FD
    mv s1, a1                 # Buffer
    mv s2, a2                 # Count
    
    # Validate FD
    li t0, MAX_FDS
    bgeu s0, t0, fr_error
    
    # Get FD entry
    la t0, fd_table
    slli t1, s0, 4            # FD * 16
    add t0, t0, t1
    
    # Check if open (refcount > 0)
    lw t1, 12(t0)
    beqz t1, fr_error
    
    # Get inode number
    lw s0, 0(t0)
    
    # Read inode
    mv a0, s0
    call fs_read_inode
    bnez a0, fr_error
    
    # TODO: Read data blocks
    # For now, return 0 (EOF)
    li a0, 0
    j fr_done
    
fr_error:
    li a0, -1
    
fr_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# file_write: Write to file
#
# Arguments:
#   a0 = fd
#   a1 = buffer
#   a2 = count (bytes to write)
# Returns:
#   a0 = bytes written or -1 on error
#=============================================================================
file_write:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                 # FD
    mv s1, a1                 # Buffer
    mv s2, a2                 # Count
    
    # Validate FD
    li t0, MAX_FDS
    bgeu s0, t0, fw_error
    
    # Get FD entry
    la t0, fd_table
    slli t1, s0, 4
    add t0, t0, t1
    
    # Check if open
    lw t1, 12(t0)
    beqz t1, fw_error
    
    # Get inode
    lw s0, 0(t0)
    
    # Read inode
    mv a0, s0
    call fs_read_inode
    bnez a0, fw_error
    
    # TODO: Write data blocks
    # For now, return count as written
    mv a0, s2
    j fw_done
    
fw_error:
    li a0, -1
    
fw_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# file_close: Close file
#
# Arguments:
#   a0 = fd
# Returns:
#   a0 = 0 on success, -1 on error
#=============================================================================
file_close:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Validate FD
    li t0, MAX_FDS
    bgeu s0, t0, fc_error
    
    # Get FD entry
    la t0, fd_table
    slli t1, s0, 4
    add t0, t0, t1
    
    # Check if open
    lw t1, 12(t0)
    beqz t1, fc_error
    
    # Decrement refcount
    addi t1, t1, -1
    sw t1, 12(t0)
    
    # If refcount == 0, clear entry
    bnez t1, fc_success
    sw zero, 0(t0)
    sw zero, 4(t0)
    sw zero, 8(t0)
    
fc_success:
    li a0, 0
    j fc_done
    
fc_error:
    li a0, -1
    
fc_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
