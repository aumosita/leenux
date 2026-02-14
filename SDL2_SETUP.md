# SDL2 Setup Options

## Issue

Pygame requires SDL2, but Homebrew has permission issues.

## Solution 1: Fix Homebrew Permissions (Recommended)

```bash
sudo chown -R yong /opt/homebrew
brew install sdl2 sdl2_image
pip3 install pygame
python3 Tools/fb_viewer.py framebuffer_kernel.bin
```

## Solution 2: Use Pillow (Alternative)

```bash
pip3 install pillow
# Use image-based viewer instead
```

Which would you prefer?
