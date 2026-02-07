#!/usr/bin/env python3
"""
Leenux Framebuffer Image Viewer
Converts framebuffer binary to PNG image
"""

from PIL import Image
import struct
import sys
import os

WIDTH = 1024
HEIGHT = 768
PIXEL_SIZE = 4

def framebuffer_to_image(fb_file, output_png):
    """Convert framebuffer binary to PNG image"""
    
    # Read framebuffer
    with open(fb_file, 'rb') as f:
        data = f.read(WIDTH * HEIGHT * PIXEL_SIZE)
    
    # Create image
    img = Image.new('RGB', (WIDTH, HEIGHT))
    pixels = img.load()
    
    # Convert pixels
    for y in range(HEIGHT):
        for x in range(WIDTH):
            offset = (y * WIDTH + x) * PIXEL_SIZE
            pixel = struct.unpack('<I', data[offset:offset+4])[0]
            
            # Extract RGB (assuming 0x00RRGGBB format)
            r = (pixel >> 16) & 0xFF
            g = (pixel >> 8) & 0xFF
            b = pixel & 0xFF
            
            pixels[x, y] = (r, g, b)
    
    # Save PNG
    img.save(output_png)
    print(f"✓ Saved {output_png}")
    
    # Open with default viewer
    os.system(f'open "{output_png}"')

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 fb_to_png.py <framebuffer.bin> [output.png]")
        sys.exit(1)
    
    fb_file = sys.argv[1]
    output_png = sys.argv[2] if len(sys.argv) > 2 else "framebuffer.png"
    
    print(f"Converting {fb_file} to {output_png}...")
    framebuffer_to_image(fb_file, output_png)
    print(f"✅ Done! Image opened in default viewer.")
