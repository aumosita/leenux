# Virtual Filesystem for Leenux OS
# Simple in-memory filesystem

.section .data
.globl current_dir
.globl vfs_root

# Current directory (starts at "/")
current_dir: .word str_root_path

.section .rodata

#=============================================================================
# Directory and File Strings
#=============================================================================
str_root_path: .byte "/", 0
str_dev_path: .byte "/dev", 0
str_proc_path: .byte "/proc", 0
str_etc_path: .byte "/etc", 0

# File names
str_dev_null: .byte "null", 0
str_dev_fb: .byte "fb", 0
str_proc_meminfo: .byte "meminfo", 0
str_proc_cpuinfo: .byte "cpuinfo", 0
str_etc_version: .byte "version", 0

# File contents
content_dev_null: .byte 0
content_dev_fb: .byte "Framebuffer: 1024x768x32", 0x0A, 0

content_meminfo:
    .byte "MemTotal: 256 MB", 0x0A
    .byte "MemFree: 255 MB", 0x0A, 0

content_cpuinfo:
    .byte "processor: 0", 0x0A
    .byte "hart: 0", 0x0A
    .byte "isa: rv64imac", 0x0A
    .byte "mmu: sv39", 0x0A, 0

content_version:
    .byte "Leenux OS v0.3", 0x0A
    .byte "Build: 2026-02-07", 0x0A, 0

#=============================================================================
# VFS Structure
#=============================================================================

# Root directory entry
vfs_root:
    .word str_root_path          # Name
    .word 1                      # Type: 1=dir, 0=file
    .word vfs_root_entries       # Children
    .word 3                      # Count

vfs_root_entries:
    .word vfs_dev
    .word vfs_proc
    .word vfs_etc

# /dev directory
vfs_dev:
    .word str_dev_path
    .word 1
    .word vfs_dev_entries
    .word 2

vfs_dev_entries:
    .word file_dev_null
    .word file_dev_fb

file_dev_null:
    .word str_dev_null
    .word 0                      # Type: file
    .word content_dev_null
    .word 0                      # Size

file_dev_fb:
    .word str_dev_fb
    .word 0
    .word content_dev_fb
    .word 25

# /proc directory
vfs_proc:
    .word str_proc_path
    .word 1
    .word vfs_proc_entries
    .word 2

vfs_proc_entries:
    .word file_proc_meminfo
    .word file_proc_cpuinfo

file_proc_meminfo:
    .word str_proc_meminfo
    .word 0
    .word content_meminfo
    .word 35

file_proc_cpuinfo:
    .word str_proc_cpuinfo
    .word 0
    .word content_cpuinfo
    .word 60

# /etc directory
vfs_etc:
    .word str_etc_path
    .word 1
    .word vfs_etc_entries
    .word 1

vfs_etc_entries:
    .word file_etc_version

file_etc_version:
    .word str_etc_version
    .word 0
    .word content_version
    .word 40

.section .text
.globl vfs_lookup
.globl vfs_list_dir
.globl vfs_read_file

#=============================================================================
# vfs_lookup: Find a file or directory by path
#
# Arguments: a0 = path string
# Returns: a0 = entry pointer (or 0 if not found)
#=============================================================================
vfs_lookup:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0                # Save path
    
    # Simple implementation: check against known paths
    la a1, str_root_path
    call strcmp
    beq a0, zero, lookup_root
    
    mv a0, s0
    la a1, str_dev_path
    call strcmp
    beq a0, zero, lookup_dev
    
    mv a0, s0
    la a1, str_proc_path
    call strcmp
    beq a0, zero, lookup_proc
    
    mv a0, s0
    la a1, str_etc_path
    call strcmp
    beq a0, zero, lookup_etc
    
    # Not found
    li a0, 0
    j lookup_done
    
lookup_root:
    la a0, vfs_root
    j lookup_done
    
lookup_dev:
    la a0, vfs_dev
    j lookup_done
    
lookup_proc:
    la a0, vfs_proc
    j lookup_done
    
lookup_etc:
    la a0, vfs_etc
    
lookup_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# vfs_list_dir: List directory contents
#
# Arguments: a0 = directory entry pointer
# Returns: a0 = children array pointer, a1 = count
#=============================================================================
vfs_list_dir:
    # Entry format: [name, type, children, count]
    lw a1, 12(a0)            # Count
    lw a0, 8(a0)             # Children array
    ret

#=============================================================================
# vfs_read_file: Read file content
#
# Arguments: a0 = file entry pointer
# Returns: a0 = content pointer, a1 = size
#=============================================================================
vfs_read_file:
    # Entry format: [name, type, content, size]
    lw a1, 12(a0)            # Size
    lw a0, 8(a0)             # Content
    ret

# External dependencies
.extern strcmp
