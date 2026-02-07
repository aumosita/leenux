# Simple Screen Driver for Leenux
# Implements basic character drawing

.section .text
.globl draw_char
.globl draw_string

# External font data
.extern font_5x8
.extern font_5x8_width
.extern font_5x8_height

#=============================================================================
# draw_char: Draw a character
# Arguments: 
#   a0 = char (ASCII)
#   a1 = x coordinate
#   a2 = y coordinate
#   a3 = color (0x00RRGGBB)
#=============================================================================
draw_char:
    addi sp, sp, -32
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd s2, 16(sp)
    sd s3, 24(sp)
    
    # Check ASCII range (32-126)
    li t0, 32
    blt a0, t0, draw_char_done
    li t0, 126
    bgt a0, t0, draw_char_done
    
    # Calculate font offset
    # offset = (char - 32) * 8
    addi s0, a0, -32         # s0 = index
    slli s0, s0, 3           # s0 = index * 8
    la t0, font_5x8
    add s0, s0, t0           # s0 = pointer to char data
    
    # Variables
    mv s1, a1                # s1 = current x
    mv s2, a2                # s2 = current y
    mv s3, a3                # s3 = color
    
    # Framebuffer base: 0x10003000
    # Addr = Base + (y * 1024 + x) * 4
    lui t0, 0x10003
    
    # Calculate base pixel address for (x,y)
    li t1, 1024
    mul t1, s2, t1           # y * 1024
    add t1, t1, s1           # y * 1024 + x
    slli t1, t1, 2           # * 4
    add t0, t0, t1           # t0 = pixel address
    
    # Loop 8 rows
    li t1, 0                 # row counter
    li t2, 8                 # max rows
    
draw_row_loop:
    bge t1, t2, draw_char_done
    
    # Load font byte
    lb t3, 0(s0)
    addi s0, s0, 1           # Increment font pointer
    
    # Loop 5 cols
    # Value is in t3. bits 0-4.
    # MSB (bit 4) is left-most pixel?
    # font_5x8.s says: "bits 4-0 (MSB=left)"
    # Example: '!' is 0x04 (00100). Middle pixel set.
    
    li t4, 0                 # col counter
    li t5, 5                 # max cols
    mv t6, t0                # t6 = current line pixel ptr
    
draw_col_loop:
    bge t4, t5, draw_row_done
    
    # Check bit (4 - t4)
    li a4, 4
    sub a4, a4, t4           # Shift amount
    srl a5, t3, a4
    andi a5, a5, 1
    
    # If bit set, draw pixel
    beqz a5, pixel_skip
    sw s3, 0(t6)
    
pixel_skip:
    addi t6, t6, 4           # Next pixel
    addi t4, t4, 1
    j draw_col_loop
    
draw_row_done:
    # Move to next line in FB
    li a4, 4096              # 1024 * 4
    add t0, t0, a4
    addi t1, t1, 1
    j draw_row_loop
    
draw_char_done:
    ld s3, 24(sp)
    ld s2, 16(sp)
    ld s1, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# draw_string: Draw a null-terminated string
# Arguments:
#   a0 = string pointer
#   a1 = x
#   a2 = y
#   a3 = color
#=============================================================================
draw_string:
    addi sp, sp, -32
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)
    
    mv s0, a0
    mv s1, a1
    mv s2, a2
    # a3 is color (preserved)
    
draw_string_loop:
    lbu a0, 0(s0)            # Load char
    beqz a0, draw_string_done
    
    # Save a3? No, s registers preserved it? No, a3 is arg.
    # We should save color in s3?
    # But draw_char takes a3.
    # Let's save a3 in s3?
    # Stack space 32. 4 regs saved. OK.
    # Wait, simple: just pass a3.
    
    mv a1, s1
    mv a2, s2
    # a3 already set
    
    call draw_char
    
    # Advance
    addi s0, s0, 1           # Next char
    addi s1, s1, 6           # Next X (5 + 1 spacing)
    j draw_string_loop
    
draw_string_done:
    ld s2, 24(sp)
    ld s1, 16(sp)
    ld s0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 32
    ret
