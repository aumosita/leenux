# String Utilities for Leenux OS
# Common string operations

.section .text
.globl strlen
.globl strcmp
.globl strcpy
.globl strncpy
.globl get_first_word

#=============================================================================
# strlen: Calculate string length
#
# Arguments: a0 = string pointer
# Returns: a0 = length (not including null terminator)
#=============================================================================
strlen:
    mv t0, a0                # Save start
    li t1, 0                 # Counter
    
strlen_loop:
    lbu t2, 0(t0)
    beq t2, zero, strlen_done
    addi t0, t0, 1
    addi t1, t1, 1
    j strlen_loop
    
strlen_done:
    mv a0, t1
    ret

#=============================================================================
# strcmp: Compare two strings
#
# Arguments: a0 = string1, a1 = string2
# Returns: a0 = 0 if equal, non-zero if different
#=============================================================================
strcmp:
    mv t0, a0
    mv t1, a1
    
strcmp_loop:
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    
    # Check if different
    bne t2, t3, strcmp_diff
    
    # Check if end of string
    beq t2, zero, strcmp_equal
    
    # Continue
    addi t0, t0, 1
    addi t1, t1, 1
    j strcmp_loop
    
strcmp_equal:
    li a0, 0
    ret
    
strcmp_diff:
    sub a0, t2, t3
    ret

#=============================================================================
# strcpy: Copy string
#
# Arguments: a0 = dest, a1 = src
# Returns: a0 = dest
#=============================================================================
strcpy:
    mv t0, a0                # Save dest
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

#=============================================================================
# strncpy: Copy at most n characters
#
# Arguments: a0 = dest, a1 = src, a2 = n
# Returns: a0 = dest
#=============================================================================
strncpy:
    mv t0, a0                # Save dest
    mv t1, a0
    mv t2, a1
    mv t3, a2                # n
    
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

#=============================================================================
# get_first_word: Extract first word from string
#
# Arguments: a0 = source string
# Returns: a0 = pointer to first word (same as input, modified in place)
#          a1 = length of first word
#
# Note: This function finds the first word and null-terminates it
#       The string is modified in place (space becomes null)
#=============================================================================
get_first_word:
    mv t0, a0                # Current position
    li t1, 0                 # Word length
    
gfw_loop:
    lbu t2, 0(t0)
    
    # Check for end of string
    beq t2, zero, gfw_done
    
    # Check for space
    li t3, 0x20              # Space character
    beq t2, t3, gfw_found_space
    
    # Check for tab
    li t3, 0x09              # Tab character
    beq t2, t3, gfw_found_space
    
    # Regular character, continue
    addi t0, t0, 1
    addi t1, t1, 1
    j gfw_loop
    
gfw_found_space:
    # Null-terminate at space
    sb zero, 0(t0)
    j gfw_done
    
gfw_done:
    mv a1, t1                # Return length
    ret

