# I/O Firmware for Core 1 (I/O Processor)
# 
# Purpose: Process I/O commands from Core 0 via shared memory
# Memory Layout:
#   0x20000000: Command Queue Base
#   0x20000000: Command Type (4 bytes)
#   0x20000004: Arg0 (4 bytes)
#   0x20000008: Arg1 (4 bytes)
#   0x2000000C: Arg2 (4 bytes)

.globl _start

_start:
    # Initialize stack for Core 1
    li sp, 0x100000       # Core 1 stack at 1MB
    
    # Print startup message
    li a0, 0x10000000     # UART base
    li a1, 'I'
    sb a1, 0(a0)
    li a1, 'O'
    sb a1, 0(a0)
    li a1, '\n'
    sb a1, 0(a0)

io_loop:
    # 1. Check command queue (shared memory at 0x20000000)
    li t0, 0x20000000
    lw t1, 0(t0)          # Load command type
    
    beqz t1, io_loop      # If 0 (NOP), loop
    
    # 2. Process command based on type
    li t2, 1
    beq t1, t2, cmd_print_char
    
    li t2, 2
    beq t1, t2, cmd_write_pixel
    
    li t2, 3
    beq t1, t2, cmd_flush_fb
    
    # Unknown command, clear and loop
    j clear_command

cmd_print_char:
    # Print character to UART
    lw a1, 4(t0)          # Load char from arg0
    li a0, 0x10000000     # UART base
    sb a1, 0(a0)
    j clear_command

cmd_write_pixel:
    # Write pixel to framebuffer
    lw a0, 4(t0)          # x
    lw a1, 8(t0)          # y
    lw a2, 12(t0)         # color
    
    # Calculate framebuffer address
    li t3, 0x10003000     # FB base
    li t4, 1024           # Width
    mul t5, a1, t4        # y * width
    add t5, t5, a0        # + x
    slli t5, t5, 2        # * 4 (bytes per pixel)
    add t5, t5, t3        # + FB base
    
    sw a2, 0(t5)          # Write color
    j clear_command

cmd_flush_fb:
    # Flush framebuffer (NOP for now)
    j clear_command

clear_command:
    # Clear command (mark as processed)
    li t0, 0x20000000
    sw zero, 0(t0)        # Clear command type
    j io_loop

# Infinite loop (should never reach)
hang:
    j hang
