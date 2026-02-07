#!/usr/bin/env python3
"""
Interactive Leenux Terminal Simulator
Real-time keyboard input with blinking cursor using PySDL2
Korean UTF-8 support via PIL
"""

import sdl2
import sdl2.ext
import struct
import sys
import ctypes
import time
from PIL import Image, ImageDraw, ImageFont
import os

WIDTH = 1024
HEIGHT = 768

# Korean font paths (macOS)
KOREAN_FONT_PATHS = [
    "/System/Library/Fonts/AppleSDDGothicNeo.ttc",
    "/System/Library/Fonts/AppleGothic.ttf",
    "/Library/Fonts/AppleGothic.ttf",
]

# Font data (5x8) - Complete lowercase + uppercase
FONT_5X8 = {
    # Lowercase
    'a': [0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F, 0x00],
    'b': [0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x1E, 0x00],
    'c': [0x00, 0x00, 0x0E, 0x10, 0x10, 0x10, 0x0E, 0x00],
    'd': [0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x0F, 0x00],
    'e': [0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00],
    'f': [0x06, 0x09, 0x08, 0x1C, 0x08, 0x08, 0x08, 0x00],
    'g': [0x00, 0x00, 0x0F, 0x11, 0x11, 0x0F, 0x01, 0x0E],
    'h': [0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x11, 0x00],
    'i': [0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x0E, 0x00],
    'k': [0x10, 0x10, 0x12, 0x14, 0x18, 0x14, 0x12, 0x00],
    'l': [0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00],
    'm': [0x00, 0x00, 0x1A, 0x15, 0x15, 0x11, 0x11, 0x00],
    'n': [0x00, 0x00, 0x16, 0x19, 0x11, 0x11, 0x11, 0x00],
    'o': [0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'p': [0x00, 0x00, 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10],
    'r': [0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10, 0x00],
    's': [0x00, 0x00, 0x0F, 0x10, 0x0E, 0x01, 0x1E, 0x00],
    't': [0x08, 0x08, 0x1C, 0x08, 0x08, 0x09, 0x06, 0x00],
    'u': [0x00, 0x00, 0x11, 0x11, 0x11, 0x13, 0x0D, 0x00],
    'v': [0x00, 0x00, 0x11, 0x11, 0x11, 0x0A, 0x04, 0x00],
    'w': [0x00, 0x00, 0x11, 0x11, 0x15, 0x15, 0x0A, 0x00],
    'x': [0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x00],
    'y': [0x00, 0x00, 0x11, 0x11, 0x0F, 0x01, 0x0E, 0x00],
    'z': [0x00, 0x00, 0x1F, 0x02, 0x04, 0x08, 0x1F, 0x00],
    # Uppercase
    'A': [0x0E, 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x00],
    'B': [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E, 0x00],
    'C': [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E, 0x00],
    'D': [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E, 0x00],
    'E': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F, 0x00],
    'H': [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11, 0x00],
    'L': [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F, 0x00],
    'N': [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x00],
    'O': [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'R': [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11, 0x00],
    'S': [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E, 0x00],
    'T': [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x00],
    'U': [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E, 0x00],
    'W': [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A, 0x00],
    # Numbers
    '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E, 0x00],
    '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E, 0x00],
    '2': [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F, 0x00],
    '3': [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E, 0x00],
    '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02, 0x00],
    '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E, 0x00],
    '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E, 0x00],
    '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08, 0x00],
    '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E, 0x00],
    '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C, 0x00],
    # Symbols
    '>': [0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08, 0x00],
    '<': [0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02, 0x00],
    '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00, 0x00],
    ':': [0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x00, 0x00],
    '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00],
    ',': [0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x04, 0x08],
    '"': [0x14, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    "'": [0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    '!': [0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04, 0x00],
    '/': [0x01, 0x01, 0x02, 0x04, 0x08, 0x10, 0x10, 0x00],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
}

# Terminal dimensions
TERM_WIDTH = 80
TERM_HEIGHT = 30
MARGIN_X = 10
MARGIN_Y = 50

# Classic Mac OS Colors (System 7 era)
COLOR_BG = 0x00F5F5DC        # Beige/Cream background
COLOR_TEXT = 0x00000000      # Black text
COLOR_PROMPT = 0x000066CC    # Classic Mac blue
COLOR_CURSOR = 0x00000000    # Black cursor
COLOR_ACCENT = 0x0099CCFF    # Pastel blue for highlights

class Terminal:
    def __init__(self):
        self.cursor_x = 0
        self.cursor_y = 0
        self.command_line = ""
        self.cursor_visible = True
        self.last_blink = time.time()
        self.history = []  # Command history to display
        
        # Load Korean font
        self.korean_font = None
        for font_path in KOREAN_FONT_PATHS:
            if os.path.exists(font_path):
                try:
                    self.korean_font = ImageFont.truetype(font_path, 16)  # Larger font
                    print(f"✓ Korean font loaded: {os.path.basename(font_path)}")
                    break
                except Exception as e:
                    continue
        
        if not self.korean_font:
            print("⚠️  Korean font not found, Korean text may not display correctly")
            try:
                self.korean_font = ImageFont.load_default()
            except:
                self.korean_font = None
        
    def draw_char(self, fb, x, y, char, color):
        if char not in FONT_5X8:
            return
        char_data = FONT_5X8[char]
        for row in range(8):
            byte = char_data[row]
            for bit in range(5):
                if byte & (0x10 >> bit):
                    px = x + bit
                    py = y + row
                    if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                        offset = (py * WIDTH + px) * 4
                        fb[offset:offset+4] = struct.pack('<I', color)
    
    def draw_char_pil(self, fb, x, y, char, color):
        """Draw Unicode character using PIL"""
        if not self.korean_font:
            return 14  # Return width even if font failed
        
        # Create larger image with padding
        img = Image.new('RGB', (20, 20), (245, 245, 220))  # Beige background, no alpha
        draw = ImageDraw.Draw(img)
        
        # Draw character with better positioning
        rgb = ((color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF)
        draw.text((2, 1), char, font=self.korean_font, fill=rgb)
        
        # Copy to framebuffer
        pixels = img.load()
        for dy in range(16):
            for dx in range(16):
                px = x + dx
                py = y + dy
                if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                    r, g, b = pixels[dx, dy]
                    # Don't draw beige background pixels
                    if not (r == 245 and g == 245 and b == 220):
                        offset = (py * WIDTH + px) * 4
                        fb[offset:offset+4] = struct.pack('BBBB', b, g, r, 255)
        
        return 14  # Korean character width
    
    def draw_string(self, fb, x, y, text, color):
        cx = x
        for char in text:
            if ord(char) < 128 and char in FONT_5X8:
                # ASCII: use bitmap
                self.draw_char(fb, cx, y, char, color)
                cx += 6
            else:
                # Korean/Unicode: use PIL
                width = self.draw_char_pil(fb, cx, y, char, color)
                cx += width
    
    def draw_cursor(self, fb):
        if not self.cursor_visible:
            return
        # Draw cursor as vertical line
        x = MARGIN_X + self.cursor_x * 6
        y = MARGIN_Y + self.cursor_y * 8
        for dy in range(8):
            for dx in range(2):
                px = x + dx
                py = y + dy
                if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                    offset = (py * WIDTH + px) * 4
                    fb[offset:offset+4] = struct.pack('<I', COLOR_CURSOR)
    
    def update_blink(self):
        now = time.time()
        if now - self.last_blink > 0.5:  # Blink every 500ms
            self.cursor_visible = not self.cursor_visible
            self.last_blink = now
    
    def render(self, fb):
        # Clear screen
        for i in range(0, len(fb), 4):
            fb[i:i+4] = struct.pack('<I', COLOR_BG)
        
        # Draw history (last 25 lines)
        y_offset = MARGIN_Y
        for i, line in enumerate(self.history[-25:]):
            self.draw_string(fb, MARGIN_X, y_offset, line, COLOR_TEXT)
            y_offset += 10  # 8px char height + 2px spacing
        
        # Draw current prompt
        self.draw_string(fb, MARGIN_X, y_offset, "leenux> ", COLOR_PROMPT)
        
        # Draw command line
        if self.command_line:
            self.draw_string(fb, MARGIN_X + 8 * 6, y_offset, self.command_line, COLOR_TEXT)
        
        # Draw cursor
        self.cursor_x = 8 + len(self.command_line)
        self.cursor_y = 0  # Relative to current line
        cursor_x_px = MARGIN_X + self.cursor_x * 6
        cursor_y_px = y_offset
        
        if self.cursor_visible:
            for dy in range(8):
                for dx in range(2):
                    px = cursor_x_px + dx
                    py = cursor_y_px + dy
                    if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                        offset = (py * WIDTH + px) * 4
                        fb[offset:offset+4] = struct.pack('<I', COLOR_CURSOR)

def main():
    print("🖥️  Leenux Interactive Terminal Simulator")
    print("=" * 50)
    
    # Initialize SDL2
    if sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO) != 0:
        print(f"SDL2 Error: {sdl2.SDL_GetError()}")
        return 1
    
    # Create window
    window = sdl2.SDL_CreateWindow(
        b"Leenux Terminal - Interactive",
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
        sdl2.SDL_DestroyRenderer(renderer)
        sdl2.SDL_DestroyWindow(window)
        sdl2.SDL_Quit()
        return 1
    
    print("✓ SDL2 window created")
    print("\nControls:")
    print("  Type to enter text (한글 지원!)")
    print("  Enter - Execute command")
    print("  Backspace - Delete character")
    print("  Q - Quit")
    print("\nTerminal ready!\n")
    
    # Enable text input for UTF-8 (Korean, etc.)
    sdl2.SDL_StartTextInput()
    
    # Terminal state
    term = Terminal()
    pixels = (ctypes.c_uint8 * (WIDTH * HEIGHT * 4))()
    
    # Event loop
    running = True
    event = sdl2.SDL_Event()
    
    while running:
        while sdl2.SDL_PollEvent(ctypes.byref(event)) != 0:
            if event.type == sdl2.SDL_QUIT:
                running = False
            
            elif event.type == sdl2.SDL_TEXTINPUT:
                # Handle UTF-8 text input (Korean, emoji, etc.)
                text = event.text.text.decode('utf-8')
                if len(term.command_line) < 60:
                    term.command_line += text
            
            elif event.type == sdl2.SDL_KEYDOWN:
                key = event.key.keysym.sym
                mod = event.key.keysym.mod
                
                if key == sdl2.SDLK_q:
                    running = False
                
                elif key == sdl2.SDLK_RETURN:
                    # Execute command
                    if term.command_line.strip():
                        # Add command to history
                        term.history.append(f"leenux> {term.command_line}")
                        
                        # Simple command processing
                        cmd = term.command_line.strip()
                        if cmd.startswith("echo "):
                            output = cmd[5:]
                            term.history.append(output)
                        elif cmd == "clear":
                            term.history = []
                        elif cmd == "help":
                            term.history.append("Available commands:")
                            term.history.append("  echo <text>  - Print text")
                            term.history.append("  clear        - Clear screen")
                            term.history.append("  help         - Show this help")
                            term.history.append("  uname        - System information")
                            term.history.append("  ls [dir]     - List directory")
                            term.history.append("  cat <file>   - Show file content")
                            term.history.append("  pwd          - Current directory")
                            term.history.append("  cd <dir>     - Change directory")
                            term.history.append("  free         - Memory usage")
                            term.history.append("  malloc <n>   - Test allocation")
                            term.history.append("  memtest      - Test allocator")
                        elif cmd == "uname":
                            term.history.append("Leenux OS v0.3 (RISC-V RV64I)")
                            term.history.append("Kernel: Bare-metal")
                            term.history.append("RAM: 256 MB")
                        elif cmd == "ls":
                            term.history.append("dev")
                            term.history.append("proc")
                            term.history.append("etc")
                        elif cmd == "ls /dev":
                            term.history.append("null")
                            term.history.append("fb")
                        elif cmd == "ls /proc":
                            term.history.append("meminfo")
                            term.history.append("cpuinfo")
                        elif cmd == "ls /etc":
                            term.history.append("version")
                        elif cmd == "cat /proc/meminfo":
                            term.history.append("MemTotal: 256 MB")
                            term.history.append("MemFree: 255 MB")
                        elif cmd == "cat /proc/cpuinfo":
                            term.history.append("processor: 0")
                            term.history.append("hart: 0")
                            term.history.append("isa: rv64imac")
                            term.history.append("mmu: sv39")
                        elif cmd == "cat /etc/version":
                            term.history.append("Leenux OS v0.3")
                            term.history.append("Build: 2026-02-07")
                        elif cmd == "pwd":
                            term.history.append("/")
                        elif cmd.startswith("cd "):
                            # Just acknowledge for now
                            pass
                        elif cmd == "free":
                            term.history.append("Total: 252 MB")
                            term.history.append("Used: 0 MB")
                            term.history.append("Free: 252 MB")
                        elif cmd == "malloc":
                            term.history.append("Allocated: 0x10400010")
                        elif cmd == "memtest":
                            term.history.append("Test 1: Alloc 128B -> OK")
                            term.history.append("Test 2: Alloc 256B -> OK")
                            term.history.append("Test 3: Free -> OK")
                            term.history.append("Test 4: Realloc -> OK")
                            term.history.append("Test 5: Free all -> OK")
                            term.history.append("Memtest passed!")
                        elif cmd == 'format':
                            term.history.append("Formatting disk with SFS...")
                            term.history.append("Done!")
                        elif cmd == 'df':
                            term.history.append("Disk usage:")
                            term.history.append("Total: 32 MB")
                            term.history.append("Used: 64 KB")
                            term.history.append("Free: 31.9 MB")
                            term.history.append("Inodes: 1/256")
                        elif parts[0] == 'touch':
                            if len(parts) > 1:
                                term.history.append(f"Created: {parts[1]}")
                            else:
                                term.history.append("Usage: touch <filename>")
                        elif parts[0] == 'mkdir':
                            if len(parts) > 1:
                                term.history.append(f"Created directory: {parts[1]}")
                            else:
                                term.history.append("Usage: mkdir <dirname>")
                        else:
                            term.history.append(f"Unknown command: {cmd}")
                        
                        print(f"Command: {term.command_line}")
                    term.command_line = ""
                
                elif key == sdl2.SDLK_BACKSPACE:
                    if term.command_line:
                        # Handle UTF-8 properly (remove last character)
                        term.command_line = term.command_line[:-1]
        
        # Update cursor blink
        term.update_blink()
        
        # Render
        term.render(pixels)
        
        # Update texture
        sdl2.SDL_UpdateTexture(
            texture,
            None,
            ctypes.cast(pixels, ctypes.POINTER(ctypes.c_uint8)),
            WIDTH * 4
        )
        
        # Display
        sdl2.SDL_RenderClear(renderer)
        sdl2.SDL_RenderCopy(renderer, texture, None, None)
        sdl2.SDL_RenderPresent(renderer)
        
        # Small delay
        sdl2.SDL_Delay(16)  # ~60 FPS
    
    # Cleanup
    sdl2.SDL_DestroyTexture(texture)
    sdl2.SDL_DestroyRenderer(renderer)
    sdl2.SDL_DestroyWindow(window)
    sdl2.SDL_Quit()
    
    print("\nTerminal closed.")
    return 0

if __name__ == '__main__':
    sys.exit(main())
