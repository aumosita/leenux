#!/usr/bin/env python3
"""
Generate Test Framebuffer
Creates a synthetic framebuffer mimicking the Leenux kernel output
"""

import struct

WIDTH = 1024
HEIGHT = 768
PIXEL_SIZE = 4

# Create framebuffer
fb = bytearray(WIDTH * HEIGHT * PIXEL_SIZE)

def set_pixel(x, y, color):
    """Set a pixel at (x, y) with given color (0x00RRGGBB)"""
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        offset = (y * WIDTH + x) * PIXEL_SIZE
        fb[offset:offset+4] = struct.pack('<I', color)

def fill_rect(x, y, w, h, color):
    """Fill a rectangle with color"""
    for dy in range(h):
        for dx in range(w):
            set_pixel(x + dx, y + dy, color)

def draw_char_5x8(x, y, char_data, color):
    """Draw one character (5x8 bitmap)"""
    for row in range(8):
        byte = char_data[row]
        for bit in range(5):
            if byte & (0x10 >> bit):  # Check bit 4, 3, 2, 1, 0
                set_pixel(x + bit, y + row, color)

# Font data for a few characters
FONT_5X8 = {
    'L': [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F, 0x00],
    'E': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F, 0x00],
    'N': [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x00],
    'U': [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'X': [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11, 0x00],
    'O': [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'S': [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E, 0x00],
    'H': [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11, 0x00],
    'e': [0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00],
    'l': [0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00],
    'o': [0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'W': [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A, 0x00],
    'r': [0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10, 0x00],
    'd': [0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x0F, 0x00],
    '!': [0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04, 0x00],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
}

def draw_text(x, y, text, color):
    """Draw text string"""
    cx = x
    for char in text:
        if char in FONT_5X8:
            draw_char_5x8(cx, y, FONT_5X8[char], color)
        cx += 6  # 5 pixels + 1 spacing

# Colors
DARK_BLUE = 0x00001000
WHITE = 0x00FFFFFF
GRAY = 0x00C0C0C0
GREEN = 0x0000FF00
CYAN = 0x0000FFFF
YELLOW = 0x00FFFF00

print("Generating test framebuffer...")

# 1. Background (dark blue)
fill_rect(0, 0, WIDTH, HEIGHT, DARK_BLUE)

# 2. Title
draw_text(50, 30, "LEENUX OS", WHITE)

# 3. Subtitle  
draw_text(50, 50, "Hello World!", GRAY)

# 4. Horizontal line (yellow)
fill_rect(50, 70, 200, 2, YELLOW)

# 5. System info (green)
draw_text(50, 90, "HELLO", GREEN)

# 6. Message (cyan)
draw_text(100, 150, "Hello World!", CYAN)

# 7. Large text (yellow)
draw_text(150, 300, "HELLO", YELLOW)

# Write to file
output_file = "framebuffer_test.bin"
with open(output_file, 'wb') as f:
    f.write(fb)

print(f"✓ Generated {len(fb)} bytes to {output_file}")
print(f"  Resolution: {WIDTH}x{HEIGHT}")
print(f"  Pixels: {WIDTH * HEIGHT}")
print(f"\nTo view:")
print(f"  python3 Tools/fb_viewer.py {output_file}")
