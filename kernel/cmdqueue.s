# Command Queue Helper Functions for Kernel
# 
# Provides abstraction layer for I/O operations via Command Queue
# Core 0 (CPU) writes commands, Core 1 (I/O processor) executes

.globl cmdq_print_char
.globl cmdq_write_pixel
.globl cmdq_flush_fb

# Command Queue Base
.equ CMDQ_BASE, 0x20000000
.equ CMDQ_TYPE, 0x00
.equ CMDQ_ARG0, 0x04
.equ CMDQ_ARG1, 0x08
.equ CMDQ_ARG2, 0x0C

# Command Types
.equ CMD_NOP, 0
.equ CMD_PRINT_CHAR, 1
.equ CMD_WRITE_PIXEL, 2
.equ CMD_FLUSH_FB, 3

# cmdq_print_char: Print character via Command Queue
# Arguments:
#   a0 = character to print
# Preserves: all registers except t0-t2
cmdq_print_char:
    li t0, CMDQ_BASE
    
    # Write command (no busy-wait for now)
    sw a0, CMDQ_ARG0(t0)  # Store char
    li t1, CMD_PRINT_CHAR
    sw t1, CMDQ_TYPE(t0)  # Trigger command
    
    ret

# cmdq_write_pixel: Write pixel to framebuffer
# Arguments:
#   a0 = x coordinate
#   a1 = y coordinate
#   a2 = color (RGBA)
# Preserves: all registers except t0-t2
cmdq_write_pixel:
    li t0, CMDQ_BASE
    
    # Wait for queue
1:  lw t1, CMDQ_TYPE(t0)
    bnez t1, 1b
    
    # Write arguments
    sw a0, CMDQ_ARG0(t0)  # x
    sw a1, CMDQ_ARG1(t0)  # y
    sw a2, CMDQ_ARG2(t0)  # color
    
    # Trigger
    li t1, CMD_WRITE_PIXEL
    sw t1, CMDQ_TYPE(t0)
    
    # Small delay
    li t2, 10
2:  addi t2, t2, -1
    bnez t2, 2b
    
    ret

# cmdq_flush_fb: Flush framebuffer
# Preserves: all registers except t0-t2
cmdq_flush_fb:
    li t0, CMDQ_BASE
    
    # Wait for queue
1:  lw t1, CMDQ_TYPE(t0)
    bnez t1, 1b
    
    # Trigger
    li t1, CMD_FLUSH_FB
    sw t1, CMDQ_TYPE(t0)
    
    # Small delay
    li t2, 10
2:  addi t2, t2, -1
    bnez t2, 2b
    
    ret
