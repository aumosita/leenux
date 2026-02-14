# Multicore Boot Dispatcher
# Assigns unique ID to each core and jumps to target code

.section .text
.globl _start

_start:
    # 1. Atomic ID assignment using LR/SC
    li t0, 0x10000000        # Shared address for ID counter (e.g., UART base is 0x10000000, 
                             # but we need a RAM address. Let's use 0x70000)
    li t0, 0x70000
    
retry:
    lr.w s0, (t0)            # Load current counter
    addi s1, s0, 1           # Increment
    sc.w s2, s1, (t0)        # Store back
    bnez s2, retry           # If failed, retry
    
    # s0 now contains the unique ID (0, 1, ...)
    
    # 2. Dispatch
    beqz s0, core0_boot      # Core 0: Main Kernel
    li t1, 1
    beq s0, t1, core1_boot   # Core 1: IO Firmware
    
    # Others: Hang
hang:
    j hang

core0_boot:
    # Jump to real kernel start
    # Note: real_kernel_start will be linked after this
    j main_kernel_start

core1_boot:
    # Jump to IO firmware
    j io_firmware_start

.section .data
.align 4
core_id_counter: .word 0
