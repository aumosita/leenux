#!/usr/bin/env python3
"""
Leenux OS Framebuffer Viewer using PySDL2
Real-time framebuffer display with SDL2
"""

import sdl2
import sdl2.ext
import struct
import sys
import os
import ctypes

# Display configuration
WIDTH = 1024
HEIGHT = 768
PIXEL_SIZE = 4

def load_framebuffer(filename):
    """Load framebuffer from binary file"""
    expected_size = WIDTH * HEIGHT * PIXEL_SIZE
    
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found")
        return None
    
    with open(filename, 'rb') as f:
        data = f.read(expected_size)
    
    # Pad if needed
    if len(data) < expected_size:
        data += b'\x00' * (expected_size - len(data))
    
    return data

def framebuffer_to_pixels(data):
    """Convert framebuffer data to RGB pixel array"""
    pixels = (ctypes.c_uint8 * (WIDTH * HEIGHT * 4))()
    
    for i in range(0, len(data), PIXEL_SIZE):
        pixel_idx = i // PIXEL_SIZE
        pixel = struct.unpack('<I', data[i:i+4])[0]
        
        # Extract RGB from 0x00RRGGBB
        r = (pixel >> 16) & 0xFF
        g = (pixel >> 8) & 0xFF
        b = pixel & 0xFF
        
        # Store as RGBA for SDL
        pixels[pixel_idx * 4 + 0] = r
        pixels[pixel_idx * 4 + 1] = g
        pixels[pixel_idx * 4 + 2] = b
        pixels[pixel_idx * 4 + 3] = 255  # Alpha
    
    return pixels

def main():
    if len(sys.argv) < 2:
        print("Leenux OS Framebuffer Viewer (PySDL2)")
        print("Usage: python3 pysdl2_viewer.py <framebuffer.bin>")
        print("\nControls:")
        print("  R - Reload framebuffer")
        print("  S - Save screenshot")
        print("  ESC/Q - Quit")
        sys.exit(1)
    
    fb_file = sys.argv[1]
    
    # Initialize SDL2
    if sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO) != 0:
        print(f"SDL2 Error: {sdl2.SDL_GetError()}")
        return 1
    
    # Create window
    window = sdl2.SDL_CreateWindow(
        b"Leenux OS - Framebuffer",
        sdl2.SDL_WINDOWPOS_CENTERED,
        sdl2.SDL_WINDOWPOS_CENTERED,
        WIDTH, HEIGHT,
        sdl2.SDL_WINDOW_SHOWN
    )
    
    if not window:
        print(f"Window Error: {sdl2.SDL_GetError()}")
        sdl2.SDL_Quit()
        return 1
    
    # Create renderer
    renderer = sdl2.SDL_CreateRenderer(
        window, -1,
        sdl2.SDL_RENDERER_ACCELERATED | sdl2.SDL_RENDERER_PRESENTVSYNC
    )
    
    if not renderer:
        print(f"Renderer Error: {sdl2.SDL_GetError()}")
        sdl2.SDL_DestroyWindow(window)
        sdl2.SDL_Quit()
        return 1
    
    # Create texture
    texture = sdl2.SDL_CreateTexture(
        renderer,
        sdl2.SDL_PIXELFORMAT_RGBA32,
        sdl2.SDL_TEXTUREACCESS_STREAMING,
        WIDTH, HEIGHT
    )
    
    if not texture:
        print(f"Texture Error: {sdl2.SDL_GetError()}")
        sdl2.SDL_DestroyRenderer(renderer)
        sdl2.SDL_DestroyWindow(window)
        sdl2.SDL_Quit()
        return 1
    
    print(f"Loading framebuffer from {fb_file}...")
    fb_data = load_framebuffer(fb_file)
    
    if not fb_data:
        sdl2.SDL_DestroyTexture(texture)
        sdl2.SDL_DestroyRenderer(renderer)
        sdl2.SDL_DestroyWindow(window)
        sdl2.SDL_Quit()
        return 1
    
    # Convert to pixels
    pixels = framebuffer_to_pixels(fb_data)
    
    # Update texture
    sdl2.SDL_UpdateTexture(
        texture,
        None,
        ctypes.cast(pixels, ctypes.POINTER(ctypes.c_uint8)),
        WIDTH * 4
    )
    
    print("Display ready!")
    print("\nControls:")
    print("  R - Reload framebuffer")
    print("  S - Save screenshot")
    print("  ESC/Q - Quit")
    
    # Event loop
    running = True
    event = sdl2.SDL_Event()
    
    while running:
        while sdl2.SDL_PollEvent(ctypes.byref(event)) != 0:
            if event.type == sdl2.SDL_QUIT:
                running = False
            
            elif event.type == sdl2.SDL_KEYDOWN:
                key = event.key.keysym.sym
                
                if key == sdl2.SDLK_ESCAPE or key == sdl2.SDLK_q:
                    running = False
                
                elif key == sdl2.SDLK_r:
                    # Reload framebuffer
                    print("Reloading framebuffer...")
                    fb_data = load_framebuffer(fb_file)
                    if fb_data:
                        pixels = framebuffer_to_pixels(fb_data)
                        sdl2.SDL_UpdateTexture(
                            texture,
                            None,
                            ctypes.cast(pixels, ctypes.POINTER(ctypes.c_uint8)),
                            WIDTH * 4
                        )
                        print("Reloaded!")
                
                elif key == sdl2.SDLK_s:
                    # Save screenshot
                    screenshot_file = "screenshot.png"
                    # Would need SDL_image for PNG saving
                    print("Screenshot feature requires SDL2_image")
        
        # Render
        sdl2.SDL_RenderClear(renderer)
        sdl2.SDL_RenderCopy(renderer, texture, None, None)
        sdl2.SDL_RenderPresent(renderer)
        
        # Small delay to avoid 100% CPU
        sdl2.SDL_Delay(16)  # ~60 FPS
    
    # Cleanup
    sdl2.SDL_DestroyTexture(texture)
    sdl2.SDL_DestroyRenderer(renderer)
    sdl2.SDL_DestroyWindow(window)
    sdl2.SDL_Quit()
    
    print("Viewer closed.")
    return 0

if __name__ == '__main__':
    sys.exit(main())
