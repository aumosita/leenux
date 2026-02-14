# String Utilities for Leenux OS

.section .text
.globl strlen, strcmp, strcpy, strncpy, get_first_word

strlen:
    mv t0, a0
    li t1, 0
strlen_loop:
    lbu t2, 0(t0)
    beq t2, zero, strlen_done
    addi t0, t0, 1
    addi t1, t1, 1
    j strlen_loop
strlen_done:
    mv a0, t1
    ret

strcmp:
    mv t0, a0
    mv t1, a1
strcmp_loop:
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    bne t2, t3, strcmp_diff
    beq t2, zero, strcmp_equal
    addi t0, t0, 1
    addi t1, t1, 1
    j strcmp_loop
strcmp_equal:
    li a0, 0
    ret
strcmp_diff:
    sub a0, t2, t3
    ret

strcpy:
    mv t0, a0
    mv t1, a0
    mv t2, a1
strcpy_loop:
    lbu t3, 0(t2)
    sb t3, 0(t1)
    beq t3, zero, strcpy_done
    addi t1, t1, 1
    addi t2, t2, 1
    j strcpy_loop
strcpy_done:
    mv a0, t0
    ret

strncpy:
    mv t0, a0
    mv t1, a0
    mv t2, a1
    mv t3, a2
strncpy_loop:
    beq t3, zero, strncpy_done
    lbu t4, 0(t2)
    sb t4, 0(t1)
    beq t4, zero, strncpy_done
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, -1
    j strncpy_loop
strncpy_done:
    mv a0, t0
    ret

get_first_word:
    mv t0, a0
    li t1, 0
gfw_loop:
    lbu t2, 0(t0)
    beq t2, zero, gfw_done
    li t3, 0x20
    beq t2, t3, gfw_found_space
    li t3, 0x09
    beq t2, t3, gfw_found_space
    addi t0, t0, 1
    addi t1, t1, 1
    j gfw_loop
gfw_found_space:
    sb zero, 0(t0)
gfw_done:
    mv a1, t1
    ret
