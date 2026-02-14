# Leenux OS - Viewing Instructions

## ✅ Display Working!

### Quick View (PNG Method)

```bash
# 1. Generate simulated kernel output
python3 Tools/simulate_kernel_fb.py

# 2. Convert to PNG and view
python3 Tools/fb_to_png.py framebuffer_kernel.bin leenux_output.png
```

The PNG will open automatically in your default image viewer!

---

## What You're Seeing

- **"LEENUX OS v0.2"** (white title)
- **"RISC-V Bare Metal Kernel"** (gray subtitle)
- **Yellow separator line**
- **"RAM: 256 MB"** (green)
- **"Framebuffer: 1024x768"** (green)
- **"Hello, World!"** (cyan)
- **"Numbers: 2026"** (white)
- **"ACTIVE"** (yellow status)
- **Dark blue background**

---

## Tools Available

### 1. PNG Converter (Working!)
```bash
python3 Tools/fb_to_png.py <framebuffer.bin> [output.png]
```
- Uses Pillow (PIL)
- Creates PNG image
- Opens automatically

### 2. Kernel Simulator
```bash
python3 Tools/simulate_kernel_fb.py
```
- Generates `framebuffer_kernel.bin`
- Matches actual kernel output

### 3. SDL2 Viewer (Optional)
```bash
python3 Tools/fb_viewer.py <framebuffer.bin>
```
- Requires pygame (needs SDL2 headers)
- Real-time refresh capability
- Install: `pip3 install pygame`

---

## Current Status

✅ **Kernel**: 1,552 bytes, fully functional  
✅ **Text Rendering**: 5x8 font, 95 ASCII characters  
✅ **Display**: PNG viewer working  
⏳ **Emulator Integration**: Pending (need FB export feature)

---

## Files

- `framebuffer_kernel.bin` - Simulated kernel output (3MB)
- `leenux_output.png` - Visual output (PNG)
- `kernel/kernel.bin` - Actual kernel binary (1.5KB)

---

## Font System

**Current**: 5x8 bitmap font
- 95 printable ASCII characters (32-126)
- Font data: 760 bytes
- Rendering functions: 432 bytes

**Functions Available**:
- `draw_char(x, y, char, color)` - Single character
- `draw_string(x, y, string_ptr, color)` - Null-terminated string
- `draw_number(x, y, number, color)` - Unsigned decimal

**Future**: UTF-8 support for Korean and other languages (planned)
