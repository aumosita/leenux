#!/bin/bash
# Build script for Leenux OS
# Compiles Swift kernel and assembly boot code

set -e

echo "======================================"
echo "Leenux OS Build System"
echo "======================================"
echo ""

# Directories
KERNEL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$KERNEL_DIR")"
TOOLS_DIR="$PROJECT_ROOT/Tools"
BIN_DIR="$PROJECT_ROOT/bin"

# Output files
BOOT_BIN="$KERNEL_DIR/boot.bin"
KERNEL_BIN="$KERNEL_DIR/kernel.bin"

echo "Step 1: Assembling boot code..."
python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/boot/boot.s" "$BOOT_BIN"

if [ ! -f "$BOOT_BIN" ]; then
    echo "Error: Boot assembly failed!"
    exit 1
fi

echo "Boot code assembled: $(wc -c < "$BOOT_BIN") bytes"
echo ""

echo "Step 2: Compiling Swift kernel..."
echo "Note: Swift bare-metal compilation for RISC-V is experimental"
echo "Attempting to compile Swift sources..."
echo ""

# Try to compile Swift (this may fail due to lack of RISC-V cross-compilation support)
# For now, we'll create a minimal approach
cd "$KERNEL_DIR"

# Swift doesn't natively support RISC-V cross-compilation on macOS
# We'll need to either:
# 1. Use Swift on a RISC-V system
# 2. Cross-compile Swift for RISC-V (complex)
# 3. Hand-write the Swift code as RISC-V assembly (interim solution)

echo "WARNING: Swift cross-compilation to RISC-V is not yet supported on macOS"
echo "Using hand-written assembly kernel with text rendering"
echo ""

# Check if kernel_impl.s exists
if [ ! -f "$KERNEL_DIR/kernel_impl.s" ]; then
    echo "Error: kernel_impl.s not found!"
    exit 1
fi

echo "Step 3: Assembling kernel components..."
python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/boot/boot.s" "$KERNEL_DIR/boot/boot.bin" || exit 1
echo "  ✓ boot.s ($(wc -c < "$KERNEL_DIR/boot/boot.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/font_5x8.s" "$KERNEL_DIR/font_5x8.bin" || exit 1
echo "  ✓ font_5x8.s ($(wc -c < "$KERNEL_DIR/font_5x8.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/text.s" "$KERNEL_DIR/text.bin" || exit 1
echo "  ✓ text.s ($(wc -c < "$KERNEL_DIR/text.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/string.s" "$KERNEL_DIR/string.bin" || exit 1
echo "  ✓ string.s ($(wc -c < "$KERNEL_DIR/string.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/keyboard.s" "$KERNEL_DIR/keyboard.bin" || exit 1
echo "  ✓ keyboard.s ($(wc -c < "$KERNEL_DIR/keyboard.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/terminal.s" "$KERNEL_DIR/terminal.bin" || exit 1
echo "  ✓ terminal.s ($(wc -c < "$KERNEL_DIR/terminal.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/shell.s" "$KERNEL_DIR/shell.bin" || exit 1
echo "  ✓ shell.s ($(wc -c < "$KERNEL_DIR/shell.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/commands.s" "$KERNEL_DIR/commands.bin" || exit 1
echo "  ✓ commands.s ($(wc -c < "$KERNEL_DIR/commands.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/vfs.s" "$KERNEL_DIR/vfs.bin" || exit 1
echo "  ✓ vfs.s ($(wc -c < "$KERNEL_DIR/vfs.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/mmu.s" "$KERNEL_DIR/mmu.bin" || exit 1
echo "  ✓ mmu.s ($(wc -c < "$KERNEL_DIR/mmu.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/heap.s" "$KERNEL_DIR/heap.bin" || exit 1
echo "  ✓ heap.s ($(wc -c < "$KERNEL_DIR/heap.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/disk.s" "$KERNEL_DIR/disk.bin" || exit 1
echo "  ✓ disk.s ($(wc -c < "$KERNEL_DIR/disk.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/fs.s" "$KERNEL_DIR/fs.bin" || exit 1
echo "  ✓ fs.s ($(wc -c < "$KERNEL_DIR/fs.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/file.s" "$KERNEL_DIR/file.bin" || exit 1
echo "  ✓ file.s ($(wc -c < "$KERNEL_DIR/file.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/dir.s" "$KERNEL_DIR/dir.bin" || exit 1
echo "  ✓ dir.s ($(wc -c < "$KERNEL_DIR/dir.bin") bytes)"

python3 "$TOOLS_DIR/simple_assembler.py" "$KERNEL_DIR/kernel_impl.s" "$KERNEL_DIR/kernel_impl.bin" || exit 1
echo "  ✓ kernel_impl.s ($(wc -c < "$KERNEL_DIR/kernel_impl.bin") bytes)"

echo ""
echo "Step 4: Linking kernel components..."
cat "$KERNEL_DIR/boot/boot.bin" "$KERNEL_DIR/font_5x8.bin" "$KERNEL_DIR/text.bin" "$KERNEL_DIR/string.bin" "$KERNEL_DIR/keyboard.bin" "$KERNEL_DIR/terminal.bin" "$KERNEL_DIR/shell.bin" "$KERNEL_DIR/commands.bin" "$KERNEL_DIR/vfs.bin" "$KERNEL_DIR/mmu.bin" "$KERNEL_DIR/heap.bin" "$KERNEL_DIR/disk.bin" "$KERNEL_DIR/fs.bin" "$KERNEL_DIR/file.bin" "$KERNEL_DIR/dir.bin" "$KERNEL_DIR/kernel_impl.bin" > "$KERNEL_BIN"

echo "Final kernel binary: $(wc -c < "$KERNEL_BIN") bytes"
echo ""
echo "======================================"
echo "Build complete!"
echo "======================================"
echo ""
echo "To run: $BIN_DIR/risc-emulator $KERNEL_BIN --memory 256"
echo ""
