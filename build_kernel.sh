#!/bin/bash

# Build script for full Leenux Kernel
echo "🔨 Building Leenux Kernel..."

# 1. Create temporary combined source file
echo "   Concatenating sources..."
# Order matters: Main program first (entry point), then dependencies
cat kernel/shell_full.s \
    kernel/process.s \
    kernel/trap.s \
    kernel/timer.s \
    kernel/disk.s \
    kernel/fs.s \
    kernel/string.s \
    kernel/screen.s \
    kernel/font_5x8.s \
    kernel/terminal.s \
    kernel/keyboard.s \
    > kernel/kernel_build.s 2>/dev/null

# Check if cat succeeded
if [ ! -f kernel/kernel_build.s ]; then
    echo "❌ Error: Failed to create build file"
    exit 1
fi

# 2. Assemble
echo "   Assembling..."
python3 Tools/simple_assembler.py kernel/kernel_build.s kernel/kernel.bin

# 3. Validation
if [ -f kernel/kernel.bin ]; then
    SIZE=$(wc -c < kernel/kernel.bin)
    echo "✅ Build Success! Kernel size: $SIZE bytes"
else
    echo "❌ Build Failed"
    exit 1
fi
