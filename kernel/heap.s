# Heap Allocator for Leenux OS
# First-fit algorithm with free list

.section .data
.align 16

.globl heap_start
.globl heap_end
.globl heap_initialized

heap_start: .word 0x10400000   # Heap starts at 4MB
heap_end: .word 0x20000000     # Heap ends at 256MB
heap_initialized: .word 0

# Magic number for block validation
.equ HEAP_MAGIC, 0xABCD1234
.equ MIN_BLOCK_SIZE, 32        # Minimum block size (header + data)

.section .text
.globl heap_init
.globl kmalloc
.globl kfree
.globl heap_stats

#=============================================================================
# Memory Block Header Structure (16 bytes):
#   offset 0: size (4 bytes) - total block size including header
#   offset 4: free (4 bytes) - 1 = free, 0 = allocated  
#   offset 8: next (4 bytes) - pointer to next block
#   offset 12: magic (4 bytes) - 0xABCD1234 for validation
#=============================================================================

#=============================================================================
# heap_init: Initialize the heap
#=============================================================================
heap_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    
    # Get heap start address
    la t0, heap_start
    lw s0, 0(t0)
    
    # Create initial free block
    # size = entire heap - header
    la t0, heap_end
    lw t1, 0(t0)
    sub t1, t1, s0           # Total heap size
    sw t1, 0(s0)             # Store size
    
    # free = 1
    li t2, 1
    sw t2, 4(s0)
    
    # next = null
    sw zero, 8(s0)
    
    # magic
    li t2, HEAP_MAGIC
    sw t2, 12(s0)
    
    # Mark initialized
    la t0, heap_initialized
    li t1, 1
    sw t1, 0(t0)
    
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#=============================================================================
# kmalloc: Allocate memory from heap
#
# Arguments: a0 = size (bytes to allocate)
# Returns: a0 = pointer to allocated memory (or 0 if failed)
#=============================================================================
kmalloc:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    
    mv s0, a0                # Save requested size
    
    # Check if heap initialized
    la t0, heap_initialized
    lw t0, 0(t0)
    bnez t0, kmalloc_ready
    call heap_init
    
kmalloc_ready:
    # Align size to 16 bytes
    addi s0, s0, 15
    li t0, 0xFFFFFFF0
    and s0, s0, t0
    
    # Add header size
    addi s0, s0, 16
    
    # Minimum block size check
    li t0, MIN_BLOCK_SIZE
    bge s0, t0, kmalloc_size_ok
    mv s0, t0
    
kmalloc_size_ok:
    # Start searching from heap start
    la t0, heap_start
    lw s1, 0(t0)             # Current block
    
kmalloc_search:
    beq s1, zero, kmalloc_fail
    
    # Check magic
    lw t0, 12(s1)
    li t1, HEAP_MAGIC
    bne t0, t1, kmalloc_fail
    
    # Check if free
    lw t0, 4(s1)
    beq t0, zero, kmalloc_next
    
    # Check if big enough
    lw t1, 0(s1)
    blt t1, s0, kmalloc_next
    
    # Found suitable block!
    # Check if we should split
    sub t2, t1, s0           # Remaining size
    li t3, MIN_BLOCK_SIZE
    blt t2, t3, kmalloc_no_split
    
    # Split block
    add s2, s1, s0           # Address of new block
    
    # New block header
    sw t2, 0(s2)             # size = remaining
    li t0, 1
    sw t0, 4(s2)             # free = 1
    lw t0, 8(s1)
    sw t0, 8(s2)             # next = original next
    li t0, HEAP_MAGIC
    sw t0, 12(s2)            # magic
    
    # Update current block
    sw s0, 0(s1)             # size = requested
    sw s2, 8(s1)             # next = new block
    
kmalloc_no_split:
    # Mark block as allocated
    sw zero, 4(s1)
    
    # Return pointer (block + header size)
    addi a0, s1, 16
    j kmalloc_done
    
kmalloc_next:
    lw s1, 8(s1)
    j kmalloc_search
    
kmalloc_fail:
    li a0, 0
    
kmalloc_done:
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# kfree: Free allocated memory
#
# Arguments: a0 = pointer to memory
#=============================================================================
kfree:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    beq a0, zero, kfree_done  # Null pointer check
    
    # Get block header
    addi s0, a0, -16
    
    # Validate magic
    lw t0, 12(s0)
    li t1, HEAP_MAGIC
    bne t0, t1, kfree_done    # Invalid block
    
    # Mark as free
    li t0, 1
    sw t0, 4(s0)
    
    # Coalesce with next block if free
    lw s1, 8(s0)              # Next block
    beq s1, zero, kfree_done  # No next block
    
    lw t0, 4(s1)              # Check if next is free
    beq t0, zero, kfree_done  # Next is allocated
    
    # Merge with next
    lw t0, 0(s0)              # Current size
    lw t1, 0(s1)              # Next size
    add t0, t0, t1            # Combined size
    sw t0, 0(s0)
    
    lw t1, 8(s1)              # Next's next
    sw t1, 8(s0)              # Update next pointer
    
kfree_done:
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# heap_stats: Get heap statistics
#
# Returns:
#   a0 = total heap size
#   a1 = used bytes
#   a2 = free bytes
#=============================================================================
heap_stats:
    addi sp, sp, -16
    sw s0, 12(sp)
    sw s1, 8(sp)
    
    # Initialize counters
    li s0, 0                 # Used
    li s1, 0                 # Free
    
    # Get first block
    la t0, heap_start
    lw t0, 0(t0)
    
hs_loop:
    beq t0, zero, hs_done
    
    # Validate magic
    lw t1, 12(t0)
    li t2, HEAP_MAGIC
    bne t1, t2, hs_done
    
    # Get block size
    lw t1, 0(t0)
    
    # Check if free
    lw t2, 4(t0)
    beqz t2, hs_allocated
    
    # Free block
    add s1, s1, t1
    j hs_next
    
hs_allocated:
    # Allocated block
    add s0, s0, t1
    
hs_next:
    lw t0, 8(t0)
    j hs_loop
    
hs_done:
    # Calculate total
    add a0, s0, s1
    mv a1, s0
    mv a2, s1
    
    lw s1, 8(sp)
    lw s0, 12(sp)
    addi sp, sp, 16
    ret
