# Leenux OS Development Roadmap

## Project Overview
Developing a RISC-V 64-bit Operating System and Emulator in Swift/Assembly.

## Status Summary
- **Emulator**: ✅ Complete (RV64IMAFD, Multi-Core, MMIO)
- **Kernel**: ✅ Advanced (Shell, Filesystem, Paging)
- **Integration**: ✅ Complete (Swift Terminal <-> Kernel Bridge)

---

## 📅 Development Phases

### Phase 1: Bootloader & Foundation ✅
- [x] RISC-V Emulator (Swift)
- [x] UART Output
- [x] Basic Instruction Execution
- [x] Boot Sequence (0x1000 Entry)

### Phase 2: Kernel Basics ✅
- [x] Context Setup (Stack, Global Pointer)
- [x] Basic VGA/UART Drivers
- [x] Interrupt Vector Table (Trap Handler Base)

### Phase 3: Memory Management ✅
- [x] Page Table Definition (Sv39)
- [x] Virtual Memory Mapping (Identity Mapping)
- [x] MMIO Mapping

### Phase 4: Filesystem (SFS) ✅
- [x] Simple File System Design
- [x] Disk Driver (Ramdisk)
- [x] Inode & Block Management
- [x] File Operations (read, write, open)

### Phase 5: Terminal Bridge & Shell ✅
- [x] Interactive Shell Implementation
- [x] Swift Terminal App Integration
- [x] Input Pipeline Fixes (Keyboard Buffering)
- [x] Hangul (Korean) Rendering Support

### Phase 6: Process Management (Current) 🚧
#### 6.1 Cooperative Multitasking ✅
- [x] Process Control Block (PCB)
- [x] Context Switching (`switch_context`)
- [x] Round-Robin Scheduler
- [x] `yield()` System Call
- [x] `spawn` and background task demo

#### 6.2 Preemptive Multitasking ✅
- [x] Timer Interrupt Setup (`mtvec`, `mie`)
- [x] Timer Driver (CLINT/mtime)
- [x] Trap Handler for Timer Interrupts
- [x] Automatic Context Switching (Time Slicing)

### Phase 7: User Space & System Calls ✅
- [x] User Mode (U-Mode) Configuration
- [x] System Call Interface (`ecall`)
- [x] Privilege Level Switching (mret/sret)
- [x] Basic PMP (Physical Memory Protection)

### Phase 8: Persistent Storage (Current) 🚧
- [ ] Host File Backing (`disk.img`) for Emulator
- [ ] Persistence Verification (Write -> Reboot -> Read)
- [ ] Disk Size Expansion (e.g., 32MB)

### Phase 9: Program Loader (Planned)
- [ ] ELF Header Parsing
- [ ] Loading .text/.data segments
- [ ] Executing external programs (`hello.elf`)

---

## 🛠 Technical Stack
- **Languages**: Swift (Emulator/Terminal), RISC-V Assembly (Kernel)
- **Architecture**: RISC-V 64-bit (RV64IMAFD)
- **Tools**: `riscv64-unknown-elf-**`, `make`, Swift Package Manager

## 📝 Recent Milestones
- **2024-02-XX**: Phase 6.1 Completed - Cooperative Multitasking verified with `spawn` command.
