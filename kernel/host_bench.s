# Host Optimization Benchmark
# Tests: loops, ALU ops, memory access

.section .text
.globl _start

.equ UART_BASE, 0x10000000

_start:
    li sp, 0x80000
    
    la a0, msg_start
    call uart_print
    
    # Benchmark 1: Tight loop (decode cache test)
    la a0, msg_bench1
    call uart_print
    
    li t0, 0
    li t1, 100000
bench1_loop:
    addi t0, t0, 1        # Same instruction repeated
    addi t0, t0, 1        # Will be cached
    addi t0, t0, 1
    addi t0, t0, 1
    blt t0, t1, bench1_loop
    
    la a0, msg_done
    call uart_print
    
    # Benchmark 2: ALU operations (batch execution test)
    la a0, msg_bench2
    call uart_print
    
    li s0, 100
    li s1, 200
    li t0, 0
    li t1, 50000
bench2_loop:
    add s2, s0, s1
    sub s3, s2, s0
    and s4, s1, s0
    or s5, s4, s2
    xor s6, s5, s3
    sll s7, s6, 2
    srl s8, s7, 1
    addi t0, t0, 1
    blt t0, t1, bench2_loop
    
    la a0, msg_done
    call uart_print
    
    # Benchmark 3: Memory access pattern
    la a0, msg_bench3
    call uart_print
    
    li t0, 0x20000        # Base address
    li t1, 1000
    li t2, 0
bench3_loop:
    sw t2, 0(t0)
    lw t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 1
    blt t2, t1, bench3_loop
    
    la a0, msg_done
    call uart_print
    
    # Done
    la a0, msg_complete
    call uart_print

halt:
    j halt

uart_print:
    li t0, UART_BASE
.print_loop:
    lb t1, 0(a0)
    beqz t1, .print_done
    sb t1, 0(t0)
    addi a0, a0, 1
    j .print_loop
.print_done:
    ret

.section .data
msg_start: .asciz "=== Host Optimization Benchmark ===\n"
msg_bench1: .asciz "[Benchmark 1] Decode cache (tight loop)...\n"
msg_bench2: .asciz "[Benchmark 2] Batch execution (ALU ops)...\n"
msg_bench3: .asciz "[Benchmark 3] Memory access pattern...\n"
msg_done: .asciz "  Done!\n"
msg_complete: .asciz "\n=== Benchmark complete ===\n"
