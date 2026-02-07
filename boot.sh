#!/bin/bash
# Leenux OS Boot Script

cd "$(dirname "$0")"

echo "🚀 Booting Leenux OS..."
echo ""

# Run the emulator
./bin/risc-emulator kernel/kernel.bin --memory 256 --max-cycles 5000000
