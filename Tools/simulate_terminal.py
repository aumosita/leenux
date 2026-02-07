#!/usr/bin/env python3
"""
Terminal Output Simulator
Simulates what the terminal should look like
"""

import struct
from PIL import Image

WIDTH = 1024
HEIGHT = 768

# Complete font matching kernel
FONT_5X8 = {
    'l': [0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00],
    'e': [0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00],
    'n': [0x00, 0x00, 0x16, 0x19, 0x11, 0x11, 0x11, 0x00],
    'u': [0x00, 0x00, 0x11, 0x11, 0x11, 0x13, 0x0D, 0x00],
   'x': [0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x00],
    '>': [0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08, 0x00],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
}

class Framebuffer:
    def __init__(self):
        self.fb = bytearray(WIDTH * HEIGHT * 4)
    
    def set_pixel(self, x, y, color):
        if 0 <= x < WIDTH and 0 <= y < HEIGHT:
            offset = (y * WIDTH + x) * 4
            self.fb[offset:offset+4] = struct.pack('<I', color)
    
    def fill_rect(self, x, y, w, h, color):
        for dy in range(h):
            for dx in range(w):
                self.set_pixel(x + dx, y + dy, color)
    
    def draw_char(self, x, y, char, color):
        if char not in FONT_5X8:
            return
        char_data = FONT_5X8[char]
        for row in range(8):
            byte = char_data[row]
            for bit in range(5):
                if byte & (0x10 >> bit):
                    self.set_pixel(x + bit, y + row, color)
    
    def draw_string(self, x, y, text, color):
        cx = x
        for char in text:
            self.draw_char(cx, y, char, color)
            cx += 6
    
    def save_png(self, filename):
        img = Image.new('RGB', (WIDTH, HEIGHT))
        pixels = img.load()
        for y in range(HEIGHT):
            for x in range(WIDTH):
                offset = (y * WIDTH + x) * 4
                pixel = struct.unpack('<I', self.fb[offset:offset+4])[0]
                r = (pixel >> 16) & 0xFF
                g = (pixel >> 8) & 0xFF
                b = pixel & 0xFF
                pixels[x, y] = (r, g, b)
        img.save(filename)
        print(f"✓ Saved {filename}")

# Colors
DARK_BLUE = 0x00001010
GREEN = 0x0000FF00

print("Simulating terminal output...")

fb = Framebuffer()

# Clear screen (dark blue)
fb.fill_rect(0, 0, WIDTH, HEIGHT, DARK_BLUE)

# Draw prompt at (10, 50): "leenux> "
fb.draw_string(10, 50, "leenux> ", GREEN)

output = "terminal_output.png"
fb.save_png(output)

print(f"Terminal display ready!")
print(f"\nShowing: green 'leenux> ' prompt on dark blue background")
print(f"Open {output} to view")

import os
os.system(f'open "{output}"')
