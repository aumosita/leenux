#!/usr/bin/env python3
"""
Leenux OS Framebuffer Viewer
Displays the framebuffer from the RISC-V emulator using SDL2/Pygame
"""

import pygame
import struct
import sys
import os

# Display configuration
WIDTH = 1024
HEIGHT = 768
PIXEL_SIZE = 4  # 32-bit per pixel

def load_framebuffer(filename):
    """Load framebuffer from binary file and convert to pygame surface"""
    expected_size = WIDTH * HEIGHT * PIXEL_SIZE
    
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found")
        return None
    
    file_size = os.path.getsize(filename)
    if file_size < expected_size:
        print(f"Warning: File size {file_size} is smaller than expected {expected_size}")
        print(f"Padding with zeros...")
    
    with open(filename, 'rb') as f:
        data = f.read(expected_size)
    
    # Pad if needed
    if len(data) < expected_size:
        data += b'\x00' * (expected_size - len(data))
    
    # Convert framebuffer data to RGBA format for pygame
    pixels = []
    for i in range(0, len(data), PIXEL_SIZE):
        # Read as little-endian 32-bit integer
        pixel = struct.unpack('<I', data[i:i+4])[0]
        
        # Assuming framebuffer format is 0x00RRGGBB (RGB with padding)
        # Extract RGB components
        r = (pixel >> 16) & 0xFF
        g = (pixel >> 8) & 0xFF
        b = pixel & 0xFF
        a = 255  # Fully opaque
        
        pixels.extend([r, g, b, a])
    
    # Create surface from pixel data
    surface = pygame.image.frombuffer(
        bytes(pixels), (WIDTH, HEIGHT), 'RGBA'
    )
    return surface

def main():
    if len(sys.argv) < 2:
        print("Leenux OS Framebuffer Viewer")
        print("Usage: python fb_viewer.py <framebuffer.bin>")
        print("\nTo extract framebuffer from emulator memory:")
        print("  1. Run emulator and let it execute")
        print("  2. Extract FB region from memory dump")
        print("  3. Pass the extracted file to this viewer")
        sys.exit(1)
    
    fb_file = sys.argv[1]
    
    # Initialize Pygame
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption(f"Leenux OS - {os.path.basename(fb_file)}")
    
    # Load initial framebuffer
    print(f"Loading framebuffer from {fb_file}...")
    surface = load_framebuffer(fb_file)
    
    if surface is None:
        pygame.quit()
        sys.exit(1)
    
    screen.blit(surface, (0, 0))
    pygame.display.flip()
    print("Display ready!")
    print("\nControls:")
    print("  R - Reload framebuffer")
    print("  S - Save screenshot (screenshot.png)")
    print("  ESC/Q - Quit")
    
    # Event loop
    clock = pygame.time.Clock()
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                    running = False
                
                elif event.key == pygame.K_r:
                    # Reload framebuffer
                    print("Reloading framebuffer...")
                    surface = load_framebuffer(fb_file)
                    if surface:
                        screen.blit(surface, (0, 0))
                        pygame.display.flip()
                        print("Reloaded!")
                
                elif event.key == pygame.K_s:
                    # Save screenshot
                    screenshot_file = "screenshot.png"
                    pygame.image.save(screen, screenshot_file)
                    print(f"Screenshot saved to {screenshot_file}")
        
        clock.tick(60)  # 60 FPS
    
    pygame.quit()
    print("Viewer closed.")

if __name__ == '__main__':
    main()
