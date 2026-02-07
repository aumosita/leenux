#!/bin/bash
# Build all example programs
# This script assembles all .s files in the Examples directory

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/../Examples"

echo "Building all RISC-V example programs..."
echo "========================================"

cd "$SCRIPT_DIR"

# Make assemble.sh executable
chmod +x assemble.sh

# List of example files
EXAMPLES=(
    "01_arithmetic"
    "02_memory"
    "03_branches"
    "04_function_call"
    "05_comprehensive"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

for example in "${EXAMPLES[@]}"; do
    SOURCE="$EXAMPLES_DIR/${example}.s"
    BINARY="$EXAMPLES_DIR/${example}.bin"
    
    if [ ! -f "$SOURCE" ]; then
        echo "Warning: $SOURCE not found, skipping..."
        ((FAIL_COUNT++))
        continue
    fi
    
    echo ""
    echo "Building $example..."
    echo "--------------------"
    
    if ./assemble.sh "$SOURCE" "$BINARY"; then
        echo "✅ $example.bin created successfully"
        ((SUCCESS_COUNT++))
    else
        echo "❌ Failed to build $example"
        ((FAIL_COUNT++))
    fi
done

echo ""
echo "========================================"
echo "Build Summary:"
echo "  Success: $SUCCESS_COUNT"
echo "  Failed:  $FAIL_COUNT"
echo "========================================"

if [ $FAIL_COUNT -eq 0 ]; then
    echo "All examples built successfully!"
    exit 0
else
    echo "Some examples failed to build."
    exit 1
fi
