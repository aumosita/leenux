# Leenux OS

**A RISC-V Operating System with Swift Terminal**

![Status](https://img.shields.io/badge/status-Phase%206%20Complete-success)
![Tests](https://img.shields.io/badge/tests-15%2F15%20passing-brightgreen)
![Platform](https://img.shields.io/badge/platform-RISC--V%2064-blue)

---

## 📋 Project Overview

Leenux is a from-scratch operating system targeting RISC-V 64-bit architecture, featuring:
- Custom RISC-V emulator in Swift
- Shell kernel in assembly
- Swift-based GUI terminal with Korean support
- Complete filesystem (SFS)
- Virtual memory management

## ✅ Current Status

### Phase 6: Terminal-Kernel Bridge - **COMPLETE** 🎉

**Test Results:** 15/15 passed (100%)

All core functionality validated:
- ✅ RISC-V instruction execution
- ✅ UART I/O bridge
- ✅ Shell kernel operation
- ✅ Swift Process/Pipe integration
- ✅ MMIO device routing

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│   Swift Terminal (SDL2)             │
│   - GUI rendering                   │
│   - Korean input support            │
│   - Command history                 │
└──────────────┬──────────────────────┘
               │ KernelBridge.swift
               │ (Process/Pipe)
┌──────────────▼──────────────────────┐
│   RISC-V Emulator                   │
│   - RV64I/M/A/F/D support           │
│   - MMIO devices (UART/Timer/FB)    │
│   - Memory management               │
└──────────────┬──────────────────────┘
               │ UART stdout
┌──────────────▼──────────────────────┐
│   Leenux Kernel (Assembly)          │
│   - Shell commands                  │
│   - Filesystem (SFS)                │
│   - Virtual memory                  │
└─────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Swift 5.5+
- SDL2
- Python 3 (for assembler)

### Build & Run

```bash
# Build emulator
cd risc && swift build && cd ..

# Assemble kernel
python3 Tools/simple_assembler.py kernel/shell_working.s kernel/shell_working.bin

# Run shell
./bin/risc-emulator kernel/shell_working.bin --max-cycles 300

# Run comprehensive tests
swift test/test_emulator_comprehensive.swift
```

### Expected Output
```
Leenux Shell v0.1
leenux> format
Done!
```

## 📁 Project Structure

```
Leenux/
├── kernel/               # OS kernel (RISC-V assembly)
│   ├── shell_working.s   # Shell kernel (332 bytes)
│   └── uart_test_fixed.s # UART test (44 bytes)
├── risc/                 # RISC-V emulator (Swift)
│   ├── Sources/
│   │   ├── main.swift
│   │   ├── UARTDevice.swift
│   │   └── SharedMemory.swift
│   └── Package.swift
├── Tools/
│   ├── LeenuxTerminal/   # Swift GUI terminal
│   │   └── Sources/
│   │       ├── Terminal.swift
│   │       └── KernelBridge.swift
│   └── simple_assembler.py
├── test/                 # Test suite
│   └── test_emulator_comprehensive.swift
└── bin/
    └── risc-emulator     # Compiled emulator
```

## 🧪 Testing

Run comprehensive test suite:
```bash
cd test
swift test_emulator_comprehensive.swift
```

**Test Coverage:**
- Basic execution (5 tests)
- Hardware/MMIO (3 tests)
- Stability (2 tests)
- Environment (3 tests)
- Integration (2 tests)

**Result:** 15/15 passing ✅

## 🔧 Development Phases

- [x] **Phase 1-3:** Foundation, Terminal, Swift Migration
- [x] **Phase 4:** Memory Management (Page Tables, Virtual Memory)
- [x] **Phase 5:** Filesystem (SFS, File Operations, Korean UTF-8)
- [x] **Phase 6:** Terminal-Kernel Bridge (UART I/O, Swift Integration)
- [ ] **Phase 7:** Process Management (Future)

## 🐛 Known Issues & Solutions

### 1. UART Address Encoding
**Issue:** `li t0, 0x10000000` assembles to `0x10000`  
**Solution:** Use `lui t0, 0x10000` for addresses > 4096

### 2. Character Literals
**Issue:** Assembler doesn't support `'L'` syntax  
**Solution:** Use decimal ASCII values (e.g., `li a0, 76` for 'L')

## 📚 Documentation

- [Test Report](test/test_report.md) - Comprehensive test results
- [Phase 6 Walkthrough](docs/phase6_walkthrough.md) - Implementation details
- [RELEASE_NOTES.md](RELEASE_NOTES.md) - Emulator features

## 🎯 Key Features

### RISC-V Emulator
- RV64I base instruction set
- RV64M (multiply/divide)
- Partial RV64A/F/D support
- Sequential execution model (CPI=1.0)
- MMIO devices (UART, Timer, Framebuffer, Keyboard)

### Leenux Kernel
- Shell with command interface
- Simple Filesystem (SFS)
- Virtual memory with page tables
- Korean UTF-8 support

### Swift Terminal
- SDL2-based GUI
- Korean input (Hangul Automata)
- Command history (↑↓)
- Tab completion
- Process/Pipe kernel bridge

## 📊 Metrics

| Component    | Lines  | Language | Status    |
| ------------ | ------ | -------- | --------- |
| **Emulator** | ~2,500 | Swift    | ✅ Working |
| **Kernel**   | ~6,000 | ASM/C    | ✅ Working |
| **Terminal** | ~1,200 | Swift    | ✅ Working |
| **Bridge**   | ~100   | Swift    | ✅ Working |
| **Tests**    | ~200   | Swift    | ✅ 15/15   |

## 🤝 Contributing

This is an educational project demonstrating OS development from scratch.

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- RISC-V Foundation for the instruction set architecture
- SDL2 for graphics library
- Swift community for excellent tooling

---

**Built with ❤️ for learning and exploration**

Last Updated: 2026-02-07  
Version: 0.6 (Phase 6 Complete)
