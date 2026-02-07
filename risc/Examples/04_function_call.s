# RISC-V 64I Function Call Test
# Tests: JAL, JALR, stack operations
# Entry point: 0x1000

.section .text
.globl _start

_start:
    # Initialize stack pointer
    lui x2, 0x10            # sp = 0x10000
    
    # Prepare arguments
    addi x10, x0, 5         # a0 = 5 (first argument)
    addi x11, x0, 7         # a1 = 7 (second argument)
    
    # Call add_function
    jal x1, add_function    # Call function, ra = return address
    
    # Result in x10, should be 12
    # Call multiply_by_2 function
    jal x1, multiply_by_2   # x10 = x10 * 2 = 24
    
    # Exit
    ebreak

# Function: add two numbers
# Input: x10 (a0), x11 (a1)
# Output: x10 (a0)
add_function:
    # Save return address and registers
    addi x2, x2, -16        # Allocate stack frame
    sd x1, 8(x2)            # Save return address
    sd x12, 0(x2)           # Save x12
    
    # Function body
    add x12, x10, x11       # x12 = x10 + x11
    addi x10, x12, 0        # x10 = x12 (return value)
    
    # Restore and return
    ld x12, 0(x2)           # Restore x12
    ld x1, 8(x2)            # Restore return address
    addi x2, x2, 16         # Deallocate stack frame
    jalr x0, 0(x1)          # Return (pc = ra)

# Function: multiply by 2
# Input: x10 (a0)
# Output: x10 (a0)
multiply_by_2:
    # Save return address
    addi x2, x2, -8         # Allocate stack frame
    sd x1, 0(x2)            # Save return address
    
    # Function body
    slli x10, x10, 1        # x10 = x10 << 1 (multiply by 2)
    
    # Restore and return
    ld x1, 0(x2)            # Restore return address
    addi x2, x2, 8          # Deallocate stack frame
    jalr x0, 0(x1)          # Return
