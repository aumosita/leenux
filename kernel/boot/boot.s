# RISC-V Boot Code for Leenux OS

.section .text
.globl _start

_start:
    # Set up stack for 256MB RAM
    lui sp, 0x90000
    
    # Jump must skip halt (4 bytes) to land at swiftMain
    # We need to jump forward by 8 bytes (2 instructions)
    # But since we're at PC+0, and halt is at PC+4, and swiftMain follows at PC+8...
    # Let's use a relative offset
    
    # Actually, let's just inline the jump
    # We know kernel_impl.bin starts right after boot.bin
    # boot.bin will be 12 bytes (3 instructions)
    # So from PC=0x1000, swiftMain is at 0x100C
    # From current PC (0x1004 after execution), jump +8
    
    jal zero, kernel_start
    
halt:
    j halt

kernel_start:
    # This will be overwritten by kernel_impl.bin
    # but the label helps us calculate offsets
