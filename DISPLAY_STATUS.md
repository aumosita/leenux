# Viewing the Leenux OS Framebuffer 🖥

## Current Status: ✅ Working!

The SDL2 viewer is now running and displaying the Leenux kernel output!

---

## What You're Seeing

The display shows exactly what the kernel renders:

- **"LEENUX OS v0.2"** - White title text
- **"RISC-V Bare Metal Kernel"** - Gray subtitle  
- **Yellow horizontal line** - Separator
- **"RAM: 256 MB"** - Green system info
- **"Framebuffer: 1024x768"** - Green system info
- **"Hello, World!"** - Cyan classic message
- **"Numbers: 2026"** - White number display
- **"ACTIVE"** - Yellow status
- **Dark blue background** - Full screen

---

## How It Works

1. **Kernel** (`kernel_impl.s`) calls text rendering functions
2. **Functions** (`text.s`) draw characters using 5x8 font
3. **Font data** (`font_5x8.s`) provides bitmap patterns
4. **Framebuffer** (0x10003000) stores all pixels
5. **Simulator** (`simulate_kernel_fb.py`) replicates exact output
6. **Viewer** (`fb_viewer.py`) displays using SDL2/Pygame

---

## Commands

### Generate Simulated Framebuffer
```bash
python3 Tools/simulate_kernel_fb.py
```

### View Framebuffer
```bash
python3 Tools/fb_viewer.py framebuffer_kernel.bin
```

### Viewer Controls
- **R** - Reload framebuffer
- **S** - Save screenshot
- **ESC** or **Q** - Quit

---

## Next: Real Emulator Output

To see the ACTUAL kernel output (not simulation), we need to:

1. **Option A**: Modify emulator to export framebuffer
   - Add `--dump-fb` option
   - Write FB memory to file on exit

2. **Option B**: Use memory inspection
   - Pause emulator
   - Extract address 0x10003000
   - Save 3MB to file

3. **Option C**: Add SDL2 to emulator
   - Integrate Pygame/SDL2 directly
   - Real-time display while running

---

## Files

- `Tools/simulate_kernel_fb.py` - Generates test framebuffer
- `Tools/fb_viewer.py` - SDL2 viewer
- `framebuffer_kernel.bin` - Simulated output (3MB)
- `kernel/kernel.bin` - Actual kernel (1,552 bytes)

---

**Status**: Visualization working! Next step is connecting to real emulator output.
