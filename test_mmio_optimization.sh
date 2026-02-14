#!/bin/bash
# MMIO Performance Test

cd "$(dirname "$0")"

echo "=== MMIO Optimization Performance Test ==="
echo ""

# Create test kernel
cat > kernel/mmio_test.s << 'EOF'
# MMIO Performance Test
# Tests framebuffer clear performance

.section .text
.globl _start

.equ UART_BASE, 0x10000000
.equ FB_BASE, 0x10003000
.equ FB_PIXELS, 0x10004000  # FB_BASE + 0x1000

_start:
    li sp, 0x80000
    
    # Print start message
    la a0, msg_start
    call uart_print
    
    # Test 1: Clear framebuffer (old way - byte by byte)
    la a0, msg_test1
    call uart_print
    
    li t0, FB_PIXELS
    li t1, 0xFF000000     # Black color
    li t2, 786432         # 1024 * 768 pixels
    li t3, 0
    
test1_loop:
    sw t1, 0(t0)          # Store 4 bytes (1 pixel)
    addi t0, t0, 4
    addi t3, t3, 1
    blt t3, t2, test1_loop
    
    la a0, msg_done
    call uart_print
    
    # Test 2: Clear with 64-bit stores (2 pixels at once)
    la a0, msg_test2
    call uart_print
    
    li t0, FB_PIXELS
    li t1, 0xFF000000
    slli t2, t1, 32
    or t1, t1, t2         # 2 pixels in 64-bit
    li t2, 393216         # 786432 / 2
    li t3, 0
    
test2_loop:
    sd t1, 0(t0)          # Store 8 bytes (2 pixels)
    addi t0, t0, 8
    addi t3, t3, 1
    blt t3, t2, test2_loop
    
    la a0, msg_done
    call uart_print
    
    # Test 3: Multiple consecutive stores (tests store buffer)
    la a0, msg_test3
    call uart_print
    
    li t0, FB_PIXELS
    li t1, 0xFF000000
    li t2, 196608         # 786432 / 4
    li t3, 0
    
test3_loop:
    sd t1, 0(t0)          # 4 stores in a row
    sd t1, 8(t0)
    sd t1, 16(t0)
    sd t1, 24(t0)
    addi t0, t0, 32
    addi t3, t3, 1
    blt t3, t2, test3_loop
    
    la a0, msg_done
    call uart_print
    
    # Done
    la a0, msg_complete
    call uart_print

halt:
    j halt

# UART print
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
msg_start: .asciz "=== MMIO Performance Test ===\n"
msg_test1: .asciz "[Test 1] 32-bit stores (1 pixel)...\n"
msg_test2: .asciz "[Test 2] 64-bit stores (2 pixels)...\n"
msg_test3: .asciz "[Test 3] Consecutive stores (4x2 pixels)...\n"
msg_done: .asciz "  Done!\n"
msg_complete: .asciz "\n=== All tests complete ===\n"
EOF

echo "[1/3] Building test kernel..."
python3 Tools/simple_assembler.py kernel/mmio_test.s kernel/mmio_test.bin 0x1000

if [ ! -f kernel/mmio_test.bin ]; then
    echo "✗ Build failed"
    exit 1
fi

SIZE=$(wc -c < kernel/mmio_test.bin)
echo "✓ Test kernel built: $SIZE bytes"
echo ""

# Test with current implementation
echo "[2/3] Testing current framebuffer implementation..."
echo "Running with 20M cycles..."

timeout 15 ./bin/risc-emulator kernel/mmio_test.bin --max-cycles 20000000 --memory 256 2>&1 | tee /tmp/mmio_result.txt

echo ""

# Extract statistics
echo "[3/3] Performance analysis..."
echo ""

CYCLES=$(grep "Cycles:" /tmp/mmio_result.txt | awk '{print $2}' 2>/dev/null || echo "0")
INSTRS=$(grep "Instructions:" /tmp/mmio_result.txt | awk '{print $2}' 2>/dev/null || echo "0")

if [ "$CYCLES" != "0" ]; then
    IPC=$(echo "scale=2; $INSTRS / $CYCLES" | bc 2>/dev/null || echo "0")
    echo "Overall Performance:"
    echo "  Cycles: $CYCLES"
    echo "  Instructions: $INSTRS"
    echo "  IPC: $IPC"
    echo ""
fi

echo "=== Expected improvements with optimizations ==="
echo ""
echo "Current (NSLock on every write):"
echo "  - Framebuffer clear: ~4-5M cycles"
echo "  - Lock overhead: 5-7x"
echo ""
echo "After Bulk Write API:"
echo "  - Framebuffer clear: ~1.5-2M cycles"
echo "  - Lock overhead: 1.5-2x"
echo "  - Improvement: 60-70% faster"
echo ""
echo "After Lock-Free Reads:"
echo "  - Read performance: No lock contention"
echo "  - Concurrent reads possible"
echo "  - Improvement: 90%+ for read-heavy workloads"
echo ""

rm -f /tmp/mmio_result.txt
