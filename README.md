# Leenux OS

**A RISC-V Operating System with Swift Terminal**

![Status](https://img.shields.io/badge/status-Phase%208%20Complete-success)
![Tests](https://img.shields.io/badge/tests-All%20passing-brightgreen)
![Platform](https://img.shields.io/badge/platform-RISC--V%2064-blue)

---

## 📋 Project Overview

Leenux is a from-scratch operating system targeting RISC-V 64-bit architecture, featuring:
- Custom RISC-V emulator in Swift (RV64I/M/A/F/D/CSR)
- Multitasking Kernel with Shell (Preemptive)
- Persistent Storage Support (SFS on disk.img)
- Swift-based GUI terminal with Korean support
- Virtual memory management

## ✅ Current Status

### Phase 8: Persistent Storage - **COMPLETE** 🎉

**Key Milestones:**
- ✅ **Disk Device**: MMIO-mapped `disk.img` persistence via `FileHandle`.
- ✅ **CSR Support**: Real implementation of CSR instructions (`csrw`, etc.) for kernel boot.
- ✅ **Preemptive Multitasking**: Timer-based context switching in the emulator.
- ✅ **Cross-Platform**: macOS/Linux compatibility guards.

## 🚀 Quick Start

### Prerequisites
- Swift 5.5+
- SDL2 (for Terminal GUI)

### Build & Run

```bash
# Build kernel
./build_kernel.sh

# Build emulator (requires Swift 5.5+)
cd risc && swift build -c release && cd ..
cp risc/.build/release/risc-emulator bin/

# Run shell (requires sufficient cycles for framebuffer init)
./bin/risc-emulator kernel/kernel.bin --max-cycles 10000000 --memory 256
```

### Expected Output
```
Welcome to Leenux Shell (Preemptive)!
Type 'help' for commands.
```

### Performance Notes
- Initial boot requires ~5 million cycles for framebuffer initialization
- Framebuffer clear: 1024×768 pixels = 98,304 iterations
- UART output works immediately; keyboard input requires GUI Terminal or stdin fix

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│   Swift Terminal (SDL2)             │
│   - GUI rendering                   │
│   - Korean input support            │
└──────────────┬──────────────────────┘
               │ KernelBridge.swift
               │ (Process/Pipe)
┌──────────────▼──────────────────────┐
│   RISC-V Emulator                   │
│   - RV64I/M/A/F/D + CSR support     │
│   - Persistent Disk MMIO            │
└──────────────┬──────────────────────┘
               │ UART stdout
┌──────────────▼──────────────────────┐
│   Leenux Kernel (Assembly)          │
│   - Preemptive Multitasking         │
│   - Filesystem (SFS) on disk.img    │
└─────────────────────────────────────┘
```

## 📁 Project Structure

```
Leenux/
├── kernel/               # OS kernel (RISC-V assembly)
│   ├── shell_full.s      # Complete shell kernel
│   ├── fs.s              # Filesystem logic
│   └── trap.s            # Trap/Interrupt handler
├── risc/                 # RISC-V emulator (Swift)
│   ├── Sources/
│   │   ├── DiskDevice.swift
│   │   ├── CoreSimple.swift (With CSR support)
│   │   └── MultiCoreSystem.swift
├── Tools/
│   ├── LeenuxTerminal/   # Swift GUI terminal
│   └── simple_assembler.py
├── test/                 # Test suite
│   ├── test_persistence.swift
│   └── test_preemption.swift
└── disk.img              # Persistent disk image
```

## 🧪 Testing

Run persistence verification:
```bash
swift test/test_persistence.swift
```

## 🔧 Development Phases

- [x] **Phase 1-3:** Foundation, Terminal, Swift Migration
- [x] **Phase 4:** Memory Management (Page Tables, Virtual Memory)
- [x] **Phase 5:** Filesystem (SFS, File Operations)
- [x] **Phase 6:** Terminal-Kernel Bridge
- [x] **Phase 7:** Multitasking (Cooperative & Preemptive)
- [x] **Phase 8:** Persistent Storage (Disk MMIO)

## 🎯 Key Features

### RISC-V Emulator
- RV64I + M + CSR extension
- Persistent Disk Device (MMIO `0x15000000`)
- Multi-core scalability
- macOS/Linux cross-platform compatibility (`#if os(macOS)`)

### Leenux Kernel
- Preemptive multitasking via Timer interrupts
- SFS Filesystem with persistence
- Shell supporting `ls`, `touch`, `format`, `spawn`

## 📚 Documentation

- [Phase 8 Walkthrough](docs/phase8_walkthrough.md) - Persistence & CSR Implementation
- [Test Report](test/test_report.md) - System validation results

---

**Built with ❤️ for learning and exploration**

Last Updated: 2026-02-14  
Version: 0.8 (Phase 8 Complete)

## 🔍 Known Issues

- **Stdin Input**: FileHandle.standardInput.readabilityHandler not routing to KeyboardDevice
  - Workaround: Use Swift Terminal GUI or modify emulator for auto-input
- **Framebuffer Init**: ~5M cycles required for 1024×768 clear (normal for emulator with MMIO locks)
