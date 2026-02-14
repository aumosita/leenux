#!/bin/bash
# RISC-V Assembly to Binary Converter
# Supports RV64IMFD when using GNU toolchain
# Usage: ./assemble.sh input.s output.bin

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.s> <output.bin>"
    echo "Example: $0 ../Examples/01_arithmetic.s ../Examples/01_arithmetic.bin"
    exit 1
fi

INPUT=$1
OUTPUT=$2
TEMP_ELF=$(mktemp /tmp/riscv_XXXXXX.elf)
TEMP_BIN=$(mktemp /tmp/riscv_XXXXXX.bin)

echo "Assembling $INPUT -> $OUTPUT"

# Check for RISC-V toolchain
if command -v riscv64-unknown-elf-as &> /dev/null; then
    AS=riscv64-unknown-elf-as
    OBJCOPY=riscv64-unknown-elf-objcopy
    OBJDUMP=riscv64-unknown-elf-objdump
elif command -v riscv64-linux-gnu-as &> /dev/null; then
    AS=riscv64-linux-gnu-as
    OBJCOPY=riscv64-linux-gnu-objcopy
    OBJDUMP=riscv64-linux-gnu-objdump
else
    echo "Error: RISC-V toolchain not found!"
    echo "Please install either:"
    echo "  - riscv64-unknown-elf-* (for macOS: brew install riscv-gnu-toolchain)"
    echo "  - riscv64-linux-gnu-* (for Linux: sudo apt-get install gcc-riscv64-linux-gnu)"
    exit 1
fi

# Assemble
echo "Step 1: Assembling..."
$AS -march=rv64imfd -o "$TEMP_ELF" "$INPUT"

# Extract .text section
echo "Step 2: Extracting binary..."
$OBJCOPY -O binary -j .text "$TEMP_ELF" "$TEMP_BIN"

# Verify the output
echo "Step 3: Verifying..."
SIZE=$(wc -c < "$TEMP_BIN")
echo "Binary size: $SIZE bytes"

# Show disassembly for verification
echo "Step 4: Disassembly:"
$OBJDUMP -d "$TEMP_ELF" | head -50

# Move to final location
mv "$TEMP_BIN" "$OUTPUT"

# Cleanup
rm -f "$TEMP_ELF"

echo "Success! Binary written to $OUTPUT"

