# Memory Management Unit (MMU) - sv39 Page Tables
# RISC-V 64-bit virtual memory support

.section .data
.align 12  # Page tables must be 4KB aligned

# Root page table (Level 2)
.globl page_table_root
page_table_root: .space 4096

# Level 1 page tables (we'll allocate dynamically later)
page_table_l1_kernel: .space 4096
page_table_l1_mmio: .space 4096

# Level 0 page tables
page_table_l0_fb: .space 4096
page_table_l0_kernel: .space 4096
page_table_l0_mmio: .space 4096

.section .text
.globl init_page_tables
.globl enable_paging
.globl map_page

# Page table entry flags
.equ PTE_V, 0x01      # Valid
.equ PTE_R, 0x02      # Read
.equ PTE_W, 0x04      # Write  
.equ PTE_X, 0x08      # Execute
.equ PTE_U, 0x10      # User
.equ PTE_G, 0x20      # Global
.equ PTE_A, 0x40      # Accessed
.equ PTE_D, 0x80      # Dirty

#=============================================================================
# init_page_tables: Initialize sv39 page table structure
#
# Creates identity mappings for:
#   0x10000000-0x103FFFFF: Framebuffer (4MB, RW)
#   0x10400000-0x104FFFFF: Kernel code/data (1MB, RWX)
#   0x14000000-0x14000FFF: Keyboard MMIO (4KB, RW)
#=============================================================================
init_page_tables:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    
    # Clear all page tables
    la s0, page_table_root
    li s1, 4096
    call memzero
    
    la s0, page_table_l1_kernel
    li s1, 4096
    call memzero
    
    la s0, page_table_l1_mmio
    li s1, 4096
    call memzero
    
    la s0, page_table_l0_fb
    li s1, 4096
    call memzero
    
    la s0, page_table_l0_kernel
    li s1, 4096
    call memzero
    
    la s0, page_table_l0_mmio
    li s1, 4096
    call memzero
    
    # Setup root page table (Level 2)
    # Entry for VPN[2] = 0x40 (0x10000000 >> 30)
    la t0, page_table_root
    la t1, page_table_l1_kernel
    srli t1, t1, 12          # Convert to PPN
    slli t1, t1, 10          # Shift to PPN position
    ori t1, t1, PTE_V        # Set valid bit
    li t2, 0x40              # VPN[2] for 0x10000000
    slli t2, t2, 3           # Each entry is 8 bytes
    add t0, t0, t2
    sd t1, 0(t0)
    
    # Entry for VPN[2] = 0x50 (0x14000000 >> 30)
    la t0, page_table_root
    la t1, page_table_l1_mmio
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_V
    li t2, 0x50
    slli t2, t2, 3
    add t0, t0, t2
    sd t1, 0(t0)
    
    # Setup L1 kernel page table
    # Entry for VPN[1] = 0 (0x10000000)
    la t0, page_table_l1_kernel
    la t1, page_table_l0_fb
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_V
    sd t1, 0(t0)
    
    # Entry for VPN[1] = 2 (0x10400000)
    la t0, page_table_l1_kernel
    la t1, page_table_l0_kernel
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_V
    li t2, 2
    slli t2, t2, 3
    add t0, t0, t2
    sd t1, 0(t0)
    
    # Setup L1 MMIO page table
    # Entry for VPN[1] = 0 (0x14000000)
    la t0, page_table_l1_mmio
    la t1, page_table_l0_mmio
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_V
    sd t1, 0(t0)
    
    # Map framebuffer pages (0x10000000-0x103FFFFF = 4MB = 1024 pages)
    li a0, 0x10000000        # Virtual address
    li a1, 0x10000000        # Physical address
    li a2, PTE_V | PTE_R | PTE_W | PTE_A | PTE_D
    li a3, 1024              # 1024 pages = 4MB
    la a4, page_table_l0_fb
    call map_pages_linear
    
    # Map kernel pages (0x10400000-0x104FFFFF = 1MB = 256 pages)
    li a0, 0x10400000
    li a1, 0x10400000
    li a2, PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D
    li a3, 256
    la a4, page_table_l0_kernel
    call map_pages_linear
    
    # Map MMIO page (0x14000000-0x14000FFF = 4KB = 1 page)
    li a0, 0x14000000
    li a1, 0x14000000
    li a2, PTE_V | PTE_R | PTE_W | PTE_A | PTE_D
    li a3, 1
    la a4, page_table_l0_mmio
    call map_pages_linear
    
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# map_pages_linear: Map contiguous pages with identity mapping
#
# Arguments:
#   a0 = virtual address start
#   a1 = physical address start
#   a2 = PTE flags
#   a3 = number of pages
#   a4 = L0 page table address
#=============================================================================
map_pages_linear:
    addi sp, sp, -32
    sw s0, 28(sp)
    sw s1, 24(sp)
    sw s2, 20(sp)
    sw s3, 16(sp)
    
    mv s0, a0                # VA
    mv s1, a1                # PA
    mv s2, a2                # Flags
    mv s3, a3                # Count
    
mpl_loop:
    beq s3, zero, mpl_done
    
    # Get VPN[0] from VA
    srli t0, s0, 12
    andi t0, t0, 0x1FF       # Extract bits [20:12]
    
    # Get PPN from PA
    srli t1, s1, 12
    slli t1, t1, 10
    or t1, t1, s2            # Add flags
    
    # Store PTE
    slli t0, t0, 3           # Index * 8
    add t2, a4, t0
    sd t1, 0(t2)
    
    # Next page
    li t0, 4096
    add s0, s0, t0
    add s1, s1, t0
    addi s3, s3, -1
    j mpl_loop
    
mpl_done:
    lw s3, 16(sp)
    lw s2, 20(sp)
    lw s1, 24(sp)
    lw s0, 28(sp)
    addi sp, sp, 32
    ret

#=============================================================================
# enable_paging: Enable sv39 virtual memory
#=============================================================================
enable_paging:
    # Get physical address of root page table
    la t0, page_table_root
    srli t0, t0, 12          # Convert to PPN
    
    # Create SATP value: MODE=8 (sv39) | PPN
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    
    # Set satp register
    csrw satp, t0
    
    # Flush TLB
    sfence.vma zero, zero
    
    ret

#=============================================================================
# memzero: Zero out memory region
#
# Arguments: s0 = address, s1 = size
#=============================================================================
memzero:
    li t0, 0
mz_loop:
    beq s1, zero, mz_done
    sb t0, 0(s0)
    addi s0, s0, 1
    addi s1, s1, -1
    j mz_loop
mz_done:
    ret

#=============================================================================
# map_page: Map single page (for future use)
#
# Arguments:
#   a0 = virtual address
#   a1 = physical address
#   a2 = flags
#=============================================================================
map_page:
    # TODO: Dynamic page mapping
    # For now, all mappings are static
    ret
