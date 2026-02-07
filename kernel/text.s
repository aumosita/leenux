# Text Rendering Functions for Leenux OS
# Provides draw_char and draw_string functions using 5x8 bitmap font

.section .text
.globl draw_char
.globl draw_string
.globl draw_number

# External font data
.extern font_5x8

#=============================================================================
# draw_char: Render a single ASCII character
#
# Arguments:
#   a0 = x coordinate (column)
#   a1 = y coordinate (row)
#   a2 = ASCII character (32-126)
#   a3 = color (32-bit RGBA: 0x00RRGGBB)
#
# Returns: none
# Clobbers: t0-t6
#=============================================================================
draw_char:
    # Save registers
    addi sp, sp, -16
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    
    # Validate character range (32-126)
    li t0, 32
    blt a2, t0, char_invalid
    li t0, 127
    bge a2, t0, char_invalid
    
    # Calculate font data address
    # font_addr = font_5x8 + (char - 32) * 8
    addi t0, a2, -32
    slli t0, t0, 3              # Multiply by 8 bytes per char
    la t1, font_5x8
    add t1, t1, t0              # t1 = address of font data
    
    # Save positions
    mv s0, a0                   # s0 = start_x
    mv s1, a1                   # s1 = current_y
    mv s2, a3                   # s2 = color
    
    # Framebuffer base
    lui s3, 0x10003
    
    # Draw 8 rows
    li t2, 8                    # Row counter
draw_char_row:
    lbu t3, 0(t1)               # Load row bitmap
    addi t1, t1, 1              # Advance to next row
    
    mv t4, s0                   # Reset x to start_x
    
    # Draw 5 pixels in this row
    li t5, 5                    # Pixel counter
    li t6, 0x10                 # Bit mask (start at bit 4)
    
draw_char_pixel:
    # Check if this pixel is set
    and a2, t3, t6
    beq a2, zero, skip_char_pixel
    
    # Calculate framebuffer address
    # addr = FB_BASE + (y * 1024 + x) * 4
    slli a2, s1, 10             # y * 1024
    add a2, a2, t4              # + x
    slli a2, a2, 2              # * 4
    add a2, s3, a2              # + FB_BASE
    
    # Write pixel
    sw s2, 0(a2)
    
skip_char_pixel:
    srli t6, t6, 1              # Shift mask right
    addi t4, t4, 1              # Next x
    addi t5, t5, -1
    bne t5, zero, draw_char_pixel
    
    # Next row
    addi s1, s1, 1
    addi t2, t2, -1
    bne t2, zero, draw_char_row
    
char_invalid:
    # Restore and return
    lw s3, 0(sp)
    lw s2, 4(sp)
    lw s1, 8(sp)
    lw s0, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# draw_string: Render a null-terminated ASCII string
#
# Arguments:
#   a0 = x coordinate (starting column)
#   a1 = y coordinate (starting row)
#   a2 = pointer to null-terminated string
#   a3 = color (32-bit RGBA)
#
# Returns: none
# Clobbers: t0-t6, uses draw_char
#=============================================================================
draw_string:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    
    mv s0, a0                   # s0 = current_x
    mv s1, a1                   # s1 = y
    mv s2, a2                   # s2 = string pointer
    mv s3, a3                   # s3 = color
    
draw_string_loop:
    lbu a2, 0(s2)               # Load character
    beq a2, zero, draw_string_done  # Null terminator
    
    # Draw this character
    mv a0, s0
    mv a1, s1
    # a2 already has character
    mv a3, s3
    call draw_char
    
    # Advance x by 6 (5 pixels + 1 space)
    addi s0, s0, 6
    addi s2, s2, 1              # Next character
    j draw_string_loop
    
draw_string_done:
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# draw_number: Render an unsigned integer in decimal
#
# Arguments:
#   a0 = x coordinate
#   a1 = y coordinate
#   a2 = number to display (32-bit unsigned)
#   a3 = color
#
#  Returns: none
# Clobbers: uses draw_char
#=============================================================================
draw_number:
    addi sp, sp, -48
    sw ra, 44(sp)
    sw s0, 40(sp)
    sw s1, 36(sp)
    sw s2, 32(sp)
    sw s3, 28(sp)
    sw s4, 24(sp)
    
    mv s0, a0                   # x
    mv s1, a1                   # y
    mv s2, a2                   # number
    mv s3, a3                   # color
    
    # Buffer for digits (max 10 digits + null)
    addi s4, sp, 0              # s4 = buffer start (use stack)
    
    # Convert number to string (reverse order)
    mv t0, s4
    mv t1, s2                   # t1 = remaining number
    
convert_loop:
    li t2, 10
    remu t3, t1, t2             # t3 = digit
    divu t1, t1, t2             # t1 = number / 10
    
    addi t3, t3, 48             # Convert to ASCII ('0' + digit)
    sb t3, 0(t0)
    addi t0, t0, 1
    
    bne t1, zero, convert_loop
    
    # Null terminate
    sb zero, 0(t0)
    
    # Reverse the string
    addi t1, t0, -1             # t1 = end of string
    mv t0, s4                   # t0 = start
    
reverse_loop:
    bge t0, t1, reverse_done
    
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    sb t3, 0(t0)
    sb t2, 0(t1)
    
    addi t0, t0, 1
    addi t1, t1, -1
    j reverse_loop
    
reverse_done:
    # Draw the string
    mv a0, s0
    mv a1, s1
    mv a2, s4                   # Buffer address
    mv a3, s3
    call draw_string
    
    lw s4, 24(sp)
    lw s3, 28(sp)
    lw s2, 32(sp)
    lw s1, 36(sp)
    lw s0, 40(sp)
    lw ra, 44(sp)
    addi sp, sp, 48
    ret
