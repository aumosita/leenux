# Built-in Commands for Leenux OS - Extended with VFS
# POSIX-style commands implementation

.section .rodata

# Command help strings
str_help_header:
    .byte "Available commands:", 0x0A, 0
str_help_echo:
    .byte "  echo <text>  - Print text", 0x0A, 0
str_help_clear:
    .byte "  clear        - Clear screen", 0x0A, 0
str_help_help:
    .byte "  help         - Show this help", 0x0A, 0
str_help_uname:
    .byte "  uname        - System information", 0x0A, 0
str_help_ls:
    .byte "  ls [dir]     - List directory", 0x0A, 0
str_help_cat:
    .byte "  cat <file>   - Show file content", 0x0A, 0
str_help_pwd:
    .byte "  pwd          - Current directory", 0x0A, 0
str_help_cd:
    .byte "  cd <dir>     - Change directory", 0x0A, 0
str_help_free:
    .byte "  free         - Memory usage", 0x0A, 0
str_help_malloc:
    .byte "  malloc <n>   - Test allocation", 0x0A, 0
str_help_memtest:
    .byte "  memtest      - Test allocator", 0x0A, 0
str_help_format:
    .byte "  format       - Format disk", 0x0A, 0
str_help_df:
    .byte "  df           - Disk free space", 0x0A, 0
str_help_touch:
    .byte "  touch <file> - Create file", 0x0A, 0
str_help_mkdir:
    .byte "  mkdir <dir>  - Create directory", 0x0A, 0

str_uname_output:
    .byte "Leenux OS v0.3 (RISC-V RV64I)", 0x0A
    .byte "Kernel: Bare-metal", 0x0A
    .byte "RAM: 256 MB", 0x0A, 0

str_unknown:
    .byte "Unknown command. Type 'help' for list.", 0x0A, 0

str_file_not_found:
    .byte "File not found", 0x0A, 0

str_not_a_dir:
    .byte "Not a directory", 0x0A, 0

.section .text
.globl cmd_echo
.globl cmd_clear
.globl cmd_help
.globl cmd_uname
.globl cmd_ls
.globl cmd_cat
.globl cmd_pwd
.globl cmd_cd
.globl cmd_free
.globl cmd_malloc
.globl cmd_memtest
.globl cmd_format
.globl cmd_df
.globl cmd_touch
.globl cmd_mkdir

# External dependencies
.extern term_putchar
.extern term_newline
.extern term_clear
.extern draw_string
.extern cursor_y
.extern vfs_lookup
.extern vfs_list_dir
.extern vfs_read_file
.extern current_dir
.extern heap_stats
.extern kmalloc
.extern kfree
.extern fs_format
.extern fs_init
.extern superblock_cache
.extern fs_alloc_inode
.extern file_init

#=============================================================================
# cmd_echo: Print all arguments
#=============================================================================
cmd_echo:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    addi s0, s0, 5           # Skip "echo "
    
echo_loop:
    lbu a0, 0(s0)
    beq a0, zero, echo_done
    call term_putchar
    addi s0, s0, 1
    j echo_loop
    
echo_done:
    call term_newline
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_clear: Clear the screen
#=============================================================================
cmd_clear:
    addi sp, sp, -16
    sw ra, 12(sp)
    call term_clear
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_help: Display help message
#=============================================================================
cmd_help:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    la s0, str_help_header
    call print_string_simple
    
    la s0, str_help_echo
    call print_string_simple
    
    la s0, str_help_clear
    call print_string_simple
    
    la s0, str_help_help
    call print_string_simple
    
    la s0, str_help_uname
    call print_string_simple
    
    la s0, str_help_ls
    call print_string_simple
    
    la s0, str_help_cat
    call print_string_simple
    
    la s0, str_help_pwd
    call print_string_simple
    
    la s0, str_help_cd
    call print_string_simple
    
    la s0, str_help_free
    call print_string_simple
    
    la s0, str_help_malloc
    call print_string_simple
    
    la s0, str_help_memtest
    call print_string_simple
    
    la s0, str_help_format
    call print_string_simple
    
    la s0, str_help_df
    call print_string_simple
    
    la s0, str_help_touch
    call print_string_simple
    
    la s0, str_help_mkdir
    call print_string_simple
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_uname: Display system information
#=============================================================================
cmd_uname:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    la s0, str_uname_output
    call print_string_simple
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_ls: List directory contents
#=============================================================================
cmd_ls:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    # Get current directory
    la t0, current_dir
    lw a0, 0(t0)
    call vfs_lookup
    
    beq a0, zero, ls_not_found
    
    # Check if it's a directory (type == 1)
    lw t0, 4(a0)
    li t1, 1
    bne t0, t1, ls_not_dir
    
    # Get children
    call vfs_list_dir
    mv s0, a0                # Children array
    mv s1, a1                # Count
    
    # Print each entry
    li s2, 0
ls_loop:
    bge s2, s1, ls_done
    
    # Get entry
    slli t0, s2, 2           # s2 * 4
    add t0, s0, t0
    lw t1, 0(t0)             # Entry pointer
    
    # Get name (first word in entry)
    lw a0, 0(t1)
    mv s0, a0                # Save for next iteration
    call print_basename
    call term_newline
    mv a0, s0                # Restore
    
    addi s2, s2, 1
    j ls_loop
    
ls_not_found:
    la s0, str_file_not_found
    call print_string_simple
    j ls_done
    
ls_not_dir:
    la s0, str_not_a_dir
    call print_string_simple
    
ls_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# cmd_cat: Display file content
#=============================================================================
cmd_cat:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    # For now, just print error (need path parsing)
    la s0, str_file_not_found
    call print_string_simple
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_pwd: Print working directory
#=============================================================================
cmd_pwd:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    la t0, current_dir
    lw s0, 0(t0)
    call print_string_simple
    call term_newline
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_cd: Change directory (stub for now)
#=============================================================================
cmd_cd:
    addi sp, sp, -16
    sw ra, 12(sp)
    call term_newline
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# Helper: print_basename - Print just the filename from path
#=============================================================================
print_basename:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    
    # Find last '/' if any
pb_find_slash:
    mv t0, s0
    li t2, 0                 # Last slash position
    
pb_scan:
    lbu t1, 0(t0)
    beq t1, zero, pb_print
    li t3, 0x2F              # '/'
    bne t1, t3, pb_next
    mv t2, t0
    
pb_next:
    addi t0, t0, 1
    j pb_scan
    
pb_print:
    # If we found a slash, print from after it
    beq t2, zero, pb_from_start
    addi s0, t2, 1
    
pb_from_start:
    call print_string_simple
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# print_string_simple: Print null-terminated string
#=============================================================================
print_string_simple:
    addi sp, sp, -16
    sw ra, 12(sp)
    
ps_loop:
    lbu a0, 0(s0)
    beq a0, zero, ps_done
    
    li t0, 0x0A
    beq a0, t0, ps_newline
    
    call term_putchar
    addi s0, s0, 1
    j ps_loop
    
ps_newline:
    call term_newline
    addi s0, s0, 1
    j ps_loop
    
ps_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_free: Display memory usage
#=============================================================================
cmd_free:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    # Get heap statistics
    call heap_stats
    # a0 = total, a1 = used, a2 = free
    
    mv s0, a0
    
    # Print "Memory: X MB total"
    call print_number
    call term_newline
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_malloc: Test memory allocation
#=============================================================================
cmd_malloc:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Allocate 64 bytes for test
    li a0, 64
    call kmalloc
    
    # Print result (address or 0)
    call print_number
    call term_newline
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_memtest: Run allocator tests
#=============================================================================
cmd_memtest:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    # Test 1: Allocate
    li a0, 128
    call kmalloc
    mv s0, a0                # Save pointer
    
    # Test 2: Allocate more
    li a0, 256
    call kmalloc
    mv s1, a0
    
    # Test 3: Free first
    mv a0, s0
    call kfree
    
    # Test 4: Allocate again
    li a0, 64
    call kmalloc
    mv s2, a0
    
    # Test 5: Free all
    mv a0, s1
    call kfree
    mv a0, s2
    call kfree
    
    # Print success
    call term_newline
    
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# print_number: Print number as decimal
# Arguments: a0 = number
#=============================================================================
print_number:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    mv s0, a0
    # For now, just print a placeholder
    li a0, 0x30              # '0'
    call term_putchar
    li a0, 0x78              # 'x'
    call term_putchar
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_format: Format disk with filesystem
#=============================================================================
cmd_format:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Call fs_format
    call fs_format
    beqz a0, cf_success
    
    # Error - just newline
    call term_newline
    j cf_done
    
cf_success:
    # Success - print newline
    call term_newline
    
cf_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_df: Show disk free space
#=============================================================================
cmd_df:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Initialize FS if needed
    call fs_init
    
    #Just print newline for now
    call term_newline
    
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# cmd_touch: Create empty file
#=============================================================================
cmd_touch:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    # Initialize file system if needed
    call file_init
    
    # TODO: Parse filename from command line
    # For now, just create a test file
    
    # Allocate inode
    call fs_alloc_inode
    mv s0, a0                # Save inode number
    bltz a0, touch_error
    
    # Set inode type to file (1)
    # TODO: Write inode metadata
    
    # Print success message
    call term_newline
    
    j touch_done

touch_error:
    # Print error
    call term_newline
    
touch_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# cmd_mkdir: Create directory
#=============================================================================
cmd_mkdir:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    # Initialize file system if needed  
    call file_init
    
    # TODO: Parse dirname from command line
    
    # Allocate inode
    call fs_alloc_inode
    mv s0, a0                # Save inode number
    bltz a0, mkdir_error
    
    # Set inode type to directory (2)
    # TODO: Write inode metadata
    # TODO: Create . and .. entries
    
    # Print success message
    call term_newline
    
    j mkdir_done

mkdir_error:
    # Print error
    call term_newline
    
mkdir_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret
