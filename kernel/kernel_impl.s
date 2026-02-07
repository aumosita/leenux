# Leenux OS Kernel - Main Entry Point with Terminal
# Phase 3: Interactive Shell

.section .text
.globl swiftMain

# External dependencies
.extern shell_init
.extern shell_loop
.extern init_page_tables
.extern enable_paging

kernel_main:
    # Initialize page tables
    call init_page_tables
    
    # Enable virtual memory
    call enable_paging
    
    # Initialize and run shell
    call shell_init
    call shell_loop
    
    # If shell exits, hang
halt:
    j halt
