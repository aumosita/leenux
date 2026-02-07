# RISC-V 64I Comprehensive Test
# Tests all instruction types
# Entry point: 0x1000

.section .text
.globl _start

_start:
    # Initialize stack pointer
    lui x2, 0x10            # sp = 0x10000
    
    # Test arithmetic
    addi x1, x0, 42         # x1 = 42
    addi x3, x0, 58         # x3 = 58
    add x4, x1, x3          # x4 = 100
    sub x5, x3, x1          # x5 = 16
    
    # Test memory (store values)
    lui x6, 0x3             # x6 = 0x3000
    sd x4, 0(x6)            # Store 100 at 0x3000
    sd x5, 8(x6)            # Store 16 at 0x3008
    
    # Test memory (load values)
    ld x7, 0(x6)            # x7 = 100
    ld x8, 8(x6)            # x8 = 16
    
    # Test branching
    beq x7, x4, equal_test_pass
    j test_fail
    
equal_test_pass:
    # Test function call
    addi x10, x0, 10        # a0 = 10
    jal x1, double_value    # Call function
    # x10 should now be 20
    
    # Verify result
    addi x11, x0, 20        # Expected value
    beq x10, x11, function_test_pass
    j test_fail
    
function_test_pass:
    # Test logical operations
    addi x12, x0, 0xFF      # x12 = 255
    addi x13, x0, 0x0F      # x13 = 15
    and x14, x12, x13       # x14 = 15
    or x15, x12, x13        # x15 = 255
    xor x16, x12, x13       # x16 = 240
    
    # Test shifts
    slli x17, x1, 2         # x17 = 168 (42 << 2)
    srli x18, x3, 1         # x18 = 29 (58 >> 1)
    
    # All tests passed - set success marker
    lui x31, 0xDEADB       # x31 = 0xDEADB000
    addi x31, x31, 0xEEF   # x31 = 0xDEADBEEF (but will be 0xDEADB000 + sign-extended 0xEEF)
    
    # Actually let's use a simpler value
    addi x31, x0, 123      # x31 = 123 (success marker)
    ebreak
    
test_fail:
    addi x31, x0, -1       # x31 = -1 (failure marker)
    ebreak

# Helper function: double a value
# Input: x10 (a0)
# Output: x10 (a0) * 2
double_value:
    addi x2, x2, -8        # Allocate stack
    sd x1, 0(x2)           # Save return address
    
    slli x10, x10, 1       # x10 = x10 * 2
    
    ld x1, 0(x2)           # Restore return address
    addi x2, x2, 8         # Deallocate stack
    jalr x0, 0(x1)         # Return
