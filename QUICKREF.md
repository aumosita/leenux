# Leenux OS - Quick Reference

## 🚀 Quick Start

```bash
# Build kernel
cd kernel && ./build.sh

# Run simulator
python3 Tools/interactive_terminal.py

# Or use emulator
./bin/risc-emulator kernel/kernel.bin --memory 256
```

---

## 📁 Project Summary

**Type**: Bare-metal RISC-V Operating System  
**Size**: 5,236 bytes kernel  
**Commands**: 13  
**Features**: Virtual memory, heap allocation, filesystem

---

## 🎯 Phase Summary

| Phase | Name       | Status | Size   | Key Features           |
| ----- | ---------- | ------ | ------ | ---------------------- |
| 1     | Emulator   | ✅      | N/A    | RISC-V RV64I, MMIO     |
| 2     | Kernel     | ✅      | 2.2 KB | Boot, text rendering   |
| 3     | Terminal   | ✅      | 3.4 KB | Shell, 8 commands, VFS |
| 4     | Memory     | ✅      | 4.4 KB | Page tables, heap      |
| 5     | Filesystem | 🔄      | 5.2 KB | Disk I/O, SFS          |

---

## 💻 Commands (13 total)

### Basic
```
echo <text>  - Print text
clear        - Clear screen
help         - Show commands
uname        - System info
ls [dir]     - List directory
cat <file>   - Show file
pwd          - Current directory
cd <dir>     - Change directory
```

### Memory
```
free         - Memory usage
malloc       - Test allocation
memtest      - Allocator tests
```

### Filesystem
```
format       - Format disk
df           - Disk free space
```

---

## 🏗️ Architecture

### Memory Map
```
0x10000000   Framebuffer (3 MB)
0x10300000   Kernel (5 KB)
0x10400000   Heap (252 MB)
0x14000000   Keyboard MMIO
0x15000000   Disk MMIO
```

### Filesystem
```
Sector 0:     Superblock
Sector 1-16:  Inodes (256)
Sector 17-32: Bitmap
Sector 33+:   Data
```

---

## 🔧 Key Technologies

- **ISA**: RISC-V RV64I
- **Memory**: sv39 paging (3-level)
- **Heap**: First-fit allocator
- **FS**: Simple File System (SFS)
- **I/O**: MMIO devices

---

## 📊 Statistics

- **Code**: ~2,500 lines (assembly)
- **Binary**: 5.1 KB
- **Commands**: 13
- **Boot**: ~500K cycles
- **Disk**: 32 MB

---

## 📚 Documentation

- `README.md` - Full project documentation
- `JOURNAL.md` - Development journal
- `MEMORY_EXPLAINED.md` - Memory management guide
- `implementation_plan.md` - Current phase plan
- `walkthrough.md` - Phase completion notes

---

## 🎨 Design

**Theme**: Classic Mac OS  
**Colors**: Beige background, black text, blue prompts  
**Philosophy**: Minimal, POSIX-like, educational

---

## 🔮 Next Steps

- [ ] File operations (open/read/write)
- [ ] Directory operations
- [ ] Enhanced commands (touch, rm, mkdir)
- [ ] Process management
- [ ] Graphics & GUI

---

**Leenux OS** - *Learning operating systems from scratch* 🎓
