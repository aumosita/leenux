#!/bin/bash
# Extract framebuffer from emulator memory dump
# Usage: ./extract_fb.sh <memory_dump_file> <output_fb.bin>

MEMORY_DUMP=$1
OUTPUT_FB=$2

if [ -z "$MEMORY_DUMP" ] || [ -z "$OUTPUT_FB" ]; then
    echo "Usage: $0 <memory_dump> <output_fb.bin>"
    echo ""
    echo "This script extracts the framebuffer region from emulator memory"
    echo "Framebuffer: 0x10003000, Size: 1024x768x4 = 3,145,728 bytes"
    exit 1
fi

# Framebuffer specifications
FB_START=0x10003000
FB_SIZE=$((1024 * 768 * 4))

echo "Extracting framebuffer..."
echo "  Source: $MEMORY_DUMP"
echo "  Output: $OUTPUT_FB"
echo "  FB Address: 0x$(printf '%X' $FB_START)"
echo "  FB Size: $FB_SIZE bytes"

# Note: This assumes memory dump starts at 0x00000000
# If memory dump starts at RAM_BASE (0x80000000), adjust skip value
# For MMIO region starting at 0x10000000, offset is 0x10003000

# Extract using dd
dd if="$MEMORY_DUMP" of="$OUTPUT_FB" \
   bs=1 skip=$FB_START count=$FB_SIZE 2>/dev/null

if [ $? -eq 0 ]; then
    ACTUAL_SIZE=$(wc -c < "$OUTPUT_FB")
    echo "✓ Extracted $ACTUAL_SIZE bytes"
    
    if [ $ACTUAL_SIZE -lt $FB_SIZE ]; then
        echo "⚠ Warning: Extracted size is smaller than expected"
        echo "  This may indicate memory dump doesn't contain full FB region"
    fi
else
    echo "✗ Extraction failed"
    exit 1
fi

echo ""
echo "To view: python3 Tools/fb_viewer.py $OUTPUT_FB"
