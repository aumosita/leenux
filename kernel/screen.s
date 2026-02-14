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
    addi sp, sp, -48
    sd s0, 40(sp)
    sd s1, 32(sp)
    sd s2, 24(sp)
    sd s3, 16(sp)
    sd ra, 8(sp)
    
    # Check ASCII range (32-126)
    li t0, 32
    blt a0, t0, draw_char_done
    li t0, 126
    bgt a0, t0, draw_char_done
    
    # Calculate font offset
    addi s0, a0, -32
    slli s0, s0, 3
    la t0, font_5x8
    add s0, s0, t0
    
    mv s1, a1
    mv s2, a2
    mv s3, a3
    
    # Base: 0x10003000
    lui t0, 0x10003
    li t1, 1024
    mul t1, s2, t1
    add t1, t1, s1
    slli t1, t1, 2
    add t0, t0, t1
    
    li t1, 0
    li t2, 8
    
draw_row_loop:
    bge t1, t2, draw_char_done
    lbu t3, 0(s0)
    addi s0, s0, 1
    
    li t4, 0
    li t5, 5
    mv t6, t0
    
draw_col_loop:
    bge t4, t5, draw_row_done
    li a4, 4
    sub a4, a4, t4
    srl a5, t3, a4
    andi a5, a5, 1
    beqz a5, pixel_skip
    sw s3, 0(t6)
    
pixel_skip:
    addi t6, t6, 4
    addi t4, t4, 1
    j draw_col_loop
    
draw_row_done:
    li a4, 4096
    add t0, t0, a4
    addi t1, t1, 1
    j draw_row_loop
    
draw_char_done:
    ld ra, 8(sp)
    ld s3, 16(sp)
    ld s2, 24(sp)
    ld s1, 32(sp)
    ld s0, 40(sp)
    addi sp, sp, 48
    ret

#=============================================================================
# draw_string: Draw a null-terminated string
# Arguments:
#   a0 = string pointer
#   a1 = x, a2 = y, a3 = color
#=============================================================================
draw_string:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    
draw_string_loop:
    lbu a0, 0(s0)
    beqz a0, draw_string_done
    mv a1, s1
    mv a2, s2
    mv a3, s3
    call draw_char
    addi s0, s0, 1
    addi s1, s1, 6
    j draw_string_loop
    
draw_string_done:
    ld s3, 8(sp)
    ld s2, 16(sp)
    ld s1, 24(sp)
    ld s0, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret
