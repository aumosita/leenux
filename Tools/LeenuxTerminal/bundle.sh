#!/bin/bash
# Bundle SDL2 with the binary for standalone distribution

set -e

echo "🔧 Creating standalone binary..."

# Paths
BINARY="Tools/LeenuxTerminal/.build/release/leenux-terminal"
OUTPUT="bin/leenux-terminal"
SDL2_LIB="/opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib"

# Copy binary
mkdir -p bin
cp "$BINARY" "$OUTPUT"

# Create libs directory next to binary
mkdir -p bin/libs

# Copy SDL2 dylib
cp "$SDL2_LIB" bin/libs/

# Change install name to look in @executable_path/libs
install_name_tool -change "$SDL2_LIB" "@executable_path/libs/libSDL2-2.0.0.dylib" "$OUTPUT"

echo "✓ Binary created: $OUTPUT"
echo "✓ SDL2 bundled: bin/libs/libSDL2-2.0.0.dylib"
echo ""
echo "Distribution package:"
echo "  bin/leenux-terminal"
echo "  bin/libs/libSDL2-2.0.0.dylib"
echo ""
echo "Test: ./bin/leenux-terminal"
