# Keyboard Driver for Leenux OS
# MMIO-based keyboard input with circular buffer

.section .data
.globl input_buffer
.globl input_head
.globl input_tail

# Circular input buffer (256 bytes)
input_buffer: .space 256
input_head: .word 0          # Write position
input_tail: .word 0          # Read position

# Keyboard MMIO addresses
.equ KB_BASE,    0x14000000
.equ KB_DATA,    0x14000000  # Data register
.equ KB_STATUS,  0x14000004  # Status register

.section .text
.globl keyboard_poll
.globl keyboard_getchar
.globl keyboard_available

#=============================================================================
# keyboard_poll: Check for keyboard input and add to buffer
#
# Called periodically (e.g., in main loop or timer interrupt)
# Returns: a0 = 1 if character was read, 0 otherwise
#=============================================================================
keyboard_poll:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0,  8(sp)
    
    # Check keyboard status (0x14000004)
    lui s0, 0x14000
    lw t0, 4(s0)             # Read status register
    
    # Check bit 0 (data ready)
    andi t0, t0, 1
    beq t0, zero, poll_no_data
    
    # Read character (0x14000000)
    lw t1, 0(s0)             # Read data register
    
    # Add to buffer
    la t2, input_buffer
    la t3, input_head
    lw t4, 0(t3)             # Load head
    
    # Calculate buffer position
    andi t5, t4, 0xFF        # Wrap to 256
    add t5, t2, t5           # buffer + head
    
    # Store character
    sb t1, 0(t5)
    
    # Increment head
    addi t4, t4, 1
    andi t4, t4, 0xFF        # Wrap around
    sw t4, 0(t3)
    
    # Return 1 (character read)
    li a0, 1
    j poll_done
    
poll_no_data:
    li a0, 0
    
poll_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# keyboard_getchar: Read one character from buffer
#
# Returns: a0 = character (0 if buffer empty)
#=============================================================================
keyboard_getchar:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)             # tail
    lw t3, 0(t1)             # head
    
    # Check if buffer empty
    beq t2, t3, getchar_empty
    
    # Read character
    la t4, input_buffer
    andi t5, t2, 0xFF
    add t5, t4, t5
    lbu a0, 0(t5)
    
    # Increment tail
    addi t2, t2, 1
    andi t2, t2, 0xFF
    sw t2, 0(t0)
    
    ret
    
getchar_empty:
    li a0, 0
    ret

#=============================================================================
# keyboard_available: Check if characters available in buffer
#
# Returns: a0 = number of characters in buffer
#=============================================================================
keyboard_available:
    la t0, input_tail
    la t1, input_head
    lw t2, 0(t0)             # tail
    lw t3, 0(t1)             # head
    
    # Calculate count (head - tail) & 0xFF
    sub a0, t3, t2
    andi a0, a0, 0xFF
    ret
