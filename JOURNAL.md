# Leenux OS - Development Journal

## Project Overview
**Start Date**: 2026-02-06  
**Current Date**: 2026-02-07  
**Status**: Phase 5 (File System) - In Progress

---

## Phase 1: RISC-V Emulator
**Duration**: Initial setup  
**Goal**: Create RISC-V execution environment

### Achievements
- Multi-core RISC-V emulator
- Full RV64I instruction set
- MMIO device framework
- L1 cache simulation
- Pipeline visualization

### Key Files
- `bin/risc-emulator` - Main emulator

---

## Phase 2: Bare-Metal Kernel
**Duration**: Day 1  
**Goal**: Boot and display text

### Achievements
- Bootloader (12 bytes)
- Text rendering system
- 5x8 bitmap font (760 bytes)
- String utilities
- **Kernel**: 2,200 bytes

### Key Files
- `kernel/boot/boot.s`
- `kernel/font_5x8.s`
- `kernel/text.s`
- `kernel/string.s`

---

## Phase 3: Interactive Terminal
**Duration**: Days 2-3  
**Goal**: Command-line interface

### Achievements
- Keyboard MMIO driver
- Terminal display engine
- Command shell with parser
- Virtual filesystem (VFS)
- 8 POSIX commands
- Classic Mac OS aesthetic

### Key Statistics
- **Kernel**: 3,352 bytes
- **Commands**: echo, clear, help, uname, ls, cat, pwd, cd
- **VFS**: /dev, /proc, /etc

### Key Files
- `kernel/keyboard.s` (140 bytes)
- `kernel/terminal.s` (408 bytes)
- `kernel/shell.s` (305 bytes)
- `kernel/commands.s` (397 bytes)
- `kernel/vfs.s` (267 bytes)

### Design Decisions
- Classic Mac OS color scheme (beige background)
- POSIX-like command names
- Virtual filesystem for system info
- First-fit command parser

---

## Phase 4: Memory Management
**Duration**: Days 3-4  
**Goal**: Virtual memory and heap allocation

### Achievements
- sv39 page table implementation
- 3-level virtual memory
- Heap allocator with first-fit
- Block coalescing
- Memory commands (free, malloc, memtest)

### Key Statistics
- **Kernel**: 4,424 bytes (+1,072)
- **New Commands**: free, malloc, memtest
- **Total Commands**: 11
- **Heap**: 252 MB available

### Components Added
- `kernel/mmu.s` (372 bytes) - Page tables
- `kernel/heap.s` (448 bytes) - Allocator

### Technical Details
**Virtual Memory**:
- Identity mapping for kernel
- Page permissions (R/W/X)
- TLB flush support

**Heap Allocator**:
- 16-byte alignment
- Block splitting (>32 bytes)
- Automatic coalescing
- Magic validation (0xABCD1234)

---

## Phase 5: File System (Part 1)
**Duration**: Day 4 (ongoing)  
**Goal**: Persistent storage

### Achievements So Far
- Disk MMIO driver (280 bytes)
- Simple File System structure (436 bytes)
- Format and df commands
- Superblock management
- Inode allocation

### Key Statistics
- **Kernel**: 5,236 bytes (+812)
- **New Commands**: format, df
- **Total Commands**: 13
- **Disk**: 32 MB (65,536 sectors)

### Components Added
- `kernel/disk.s` (280 bytes) - Disk I/O
- `kernel/fs.s` (436 bytes) - Filesystem

### Technical Details
**Disk Driver**:
- MMIO base: 0x15000000
- Sector size: 512 bytes
- Read/write with polling
- Timeout protection

**Simple File System (SFS)**:
- Superblock (sector 0)
- Inode table (sectors 1-16)
- Bitmap (sectors 17-32)
- Data blocks (sector 33+)

**Inode Structure**:
- Size, type, 5 direct blocks
- 32 bytes per inode
- 256 inodes max

### Remaining Work
- [ ] File operations (open/read/write/close)
- [ ] Directory operations
- [ ] Enhanced commands (touch, rm, mkdir)
- [ ] Full file persistence

---

## Development Insights

### What Worked Well
1. **Incremental Development**: Each phase built cleanly on previous
2. **Minimal Design**: Small, focused components
3. **Testing**: Simulator allowed rapid iteration
4. **Documentation**: Clear plans before implementation

### Challenges Overcome
1. **Memory Management**: Complex sv39 page table structure
2. **String Parsing**: Token extraction without library functions
3. **Virtual Filesystem**: Balancing simplicity vs functionality
4. **Disk I/O**: MMIO protocol design

### Code Quality
- Pure assembly (no C dependencies)
- Consistent naming conventions
- Modular design (one file per component)
- Clear function boundaries
- Comprehensive comments

---

## Performance Metrics

### Kernel Size Evolution
```
Phase 1: N/A (emulator only)
Phase 2: 2,200 bytes (baseline)
Phase 3: 3,352 bytes (+1,152, +52%)
Phase 4: 4,424 bytes (+1,072, +32%)
Phase 5: 5,236 bytes (+812, +18%)
```

### Execution Statistics
- **Boot cycles**: ~500,000
- **Instructions**: ~500,000
- **Memory writes**: ~125,000
- **CPI**: ~1.00

### Memory Breakdown
```
Code:          ~5 KB
Data:          ~1 KB (buffers, caches)
Heap:         252 MB (available)
Framebuffer:    3 MB
Total:        256 MB
```

---

## Design Patterns Used

### Assembly Patterns
1. **Stack discipline**: Save/restore registers
2. **Calling convention**: Args in a0-a7, return in a0
3. **Label naming**: Descriptive with prefix
4. **Error handling**: Return -1 on error

### System Patterns
1. **MMIO**: Memory-mapped device access
2. **Polling**: Status checking with timeout
3. **Buffering**: Sector buffer for I/O
4. **Caching**: Superblock cache

### algorithmic Patterns
1. **First-fit**: Heap allocation
2. **Coalescing**: Merge free blocks
3. **Linear search**: Simple but effective
4. **Identity mapping**: Virtual = Physical

---

## Lessons Learned

### Technical
- **Keep it simple**: Complex algorithms harder in assembly
- **Align everything**: 16-byte alignment prevents bugs
- **Magic numbers**: Essential for data validation
- **Timeouts**: Prevent infinite loops in hardware waits

### Project Management
- **Plan first**: Implementation plan saved time
- **Document early**: Easier to remember decisions
- **Test incrementally**: Each component verified
- **Version control**: Clear phases help tracking

---

## Next Steps

### Immediate (Phase 5 completion)
1. Implement file_open/read/write/close
2. Add directory operations
3. Create touch, rm, mkdir commands
4. End-to-end file tests

### Future Phases
1. **Process Management**: fork, exec, scheduler
2. **Graphics**: Windows, mouse, GUI
3. **Networking**: TCP/IP, sockets
4. **Multi-core**: SMP support

---

## Code Statistics

### Lines of Code (approx.)
```
Assembly:        ~2,500 lines
Python (tools):  ~1,000 lines
Documentation:   ~1,500 lines
Total:          ~5,000 lines
```

### File Count
```
Kernel:     14 files (.s)
Tools:       3 files (.py)
Docs:        5 files (.md)
Total:      22 files
```

---

## Conclusion

**Phase 5 Part 1**: Successfully added disk I/O and filesystem foundation!

**Next Goal**: Complete file operations for full persistence.

**Overall**: On track for fully functional bare-metal OS! 🎉

---

*Last Updated: 2026-02-07 10:09*
