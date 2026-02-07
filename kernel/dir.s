# Directory Operations for Leenux OS
# Path resolution and directory management

.section .data

# Current working directory (inode number)
.globl current_dir_inode
current_dir_inode: .word 0    # Start at root (inode 0)

.section .text
.globl dir_lookup
.globl dir_add
.globl dir_remove
.globl resolve_path

.extern fs_read_inode
.extern fs_write_inode
.extern sector_buffer
.extern disk_read_sector
.extern strcmp

# Directory entry size (32 bytes)
.equ DIRENTRY_SIZE, 32

#=============================================================================
# dir_lookup: Find entry in directory
#
# Arguments:
#   a0 = directory inode number
#   a1 = name to find (null-terminated)
# Returns:
#   a0 = inode number or -1 if not found
#=============================================================================
dir_lookup:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                 # Dir inode
    mv s1, a1                 # Name
    
    # Read directory inode
    mv a0, s0
    call fs_read_inode
    bnez a0, dl_error
    
    # TODO: Read directory data blocks
    # TODO: Search for matching name
    # For now, return -1 (not found)
    
dl_error:
    li a0, -1
    
dl_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# dir_add: Add entry to directory
#
# Arguments:
#   a0 = directory inode number
#   a1 = name (null-terminated)
#   a2 = inode number to add
# Returns:
#   a0 = 0 on success, -1 on error
#=============================================================================
dir_add:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                 # Dir inode
    mv s1, a1                 # Name
    mv s2, a2                 # New inode
    
    # Read directory inode
    mv a0, s0
    call fs_read_inode
    bnez a0, da_error
    
    # TODO: Find empty slot in directory
    # TODO: Write new entry
    # For now, return success
    
    li a0, 0
    j da_done
    
da_error:
    li a0, -1
    
da_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# dir_remove: Remove entry from directory
#
# Arguments:
#   a0 = directory inode number
#   a1 = name to remove
# Returns:
#   a0 = 0 on success, -1 on error
#=============================================================================
dir_remove:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    mv s0, a0
    mv s1, a1
    
    # TODO: Find entry
    # TODO: Mark as deleted
    
    li a0, 0
    
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# resolve_path: Resolve path to inode
#
# Arguments:
#   a0 = path string (e.g., "/dir/file")
# Returns:
#   a0 = inode number or -1 if not found
#=============================================================================
resolve_path:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Check if absolute path (starts with '/')
    lbu t0, 0(s0)
    li t1, 0x2F               # '/'
    bne t0, t1, rp_relative
    
    # Absolute: start from root (inode 0)
    li a0, 0
    j rp_done
    
rp_relative:
    # Relative: start from current dir
    la t0, current_dir_inode
    lw a0, 0(t0)
    
rp_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
