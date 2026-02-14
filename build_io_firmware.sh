#!/bin/bash

# Build I/O Firmware for Core 1

echo "🔨 Building I/O Firmware..."

# Assemble
python3 Tools/simple_assembler.py kernel/io_firmware.s kernel/io_firmware.bin 0x1000

# Validation
if [ -f kernel/io_firmware.bin ]; then
    SIZE=$(wc -c <kernel/io_firmware.bin)
    echo "✅ I/O Firmware built: $SIZE bytes"
else
    echo "❌ Build failed"
    exit 1
fi
