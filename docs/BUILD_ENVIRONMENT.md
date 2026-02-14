# Build Environment

## Verified Build Environment

**Last Updated:** 2026-02-14

### ✅ Tested Configuration

**Platform:** WSL2 (Ubuntu on Windows)  
**Swift Version:** 6.0.3 (swift-6.0.3-RELEASE)  
**Target:** x86_64-unknown-linux-gnu  
**Build Time:** ~14 seconds (release mode)  
**Binary Size:** 714 KB

### Requirements

#### Mandatory
- Swift 6.0.3 (exact version recommended)
- Python 3.x (for assembler)
- POSIX-compatible shell (bash, zsh)

#### Optional
- SDL2 (for GUI terminal)
- Git (for version control)

---

## Installation Guide

### WSL/Ubuntu

```bash
# 1. Download Swift 6.0.3
wget https://download.swift.org/swift-6.0.3-release/ubuntu2204/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu22.04.tar.gz

# 2. Extract
tar xzf swift-6.0.3-RELEASE-ubuntu22.04.tar.gz

# 3. Install
sudo mv swift-6.0.3-RELEASE-ubuntu22.04 /usr/local/swift

# 4. Add to PATH (add to ~/.bashrc for persistence)
export PATH=/usr/local/swift/usr/bin:$PATH

# 5. Verify
swift --version
# Expected: Swift version 6.0.3 (swift-6.0.3-RELEASE)
#           Target: x86_64-unknown-linux-gnu
```

### macOS

```bash
# Option 1: Download from swift.org
# https://swift.org/download/#releases

# Option 2: Install Xcode (includes Swift)
xcode-select --install

# Verify
swift --version
# Swift 6.0.3 recommended
```

### Linux (Native)

```bash
# Ubuntu 22.04
wget https://download.swift.org/swift-6.0.3-release/ubuntu2204/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0.3-RELEASE-ubuntu22.04 /usr/local/swift
export PATH=/usr/local/swift/usr/bin:$PATH

# Other distributions: check swift.org
```

---

## Build Instructions

### Clean Build

```bash
# 1. Navigate to project
cd leenux/risc

# 2. Clean previous builds
rm -rf .build

# 3. Build release
swift build -c release

# 4. Copy binary
cd ..
cp risc/.build/release/risc-emulator bin/
```

### Build Output

**Success:**
```
Building for production...
[0/4] Write sources
[1/4] Write swift-version--1BA0962812E73E12.txt
[3/5] Compiling RISC_V_Emulator ...
[4/5] Linking risc-emulator
Build complete! (14.41s)
```

**Binary Location:**
- Build: `risc/.build/release/risc-emulator`
- Runtime: `bin/risc-emulator`

---

## Compatibility Notes

### Swift Version Compatibility

| Swift Version | Status | Notes |
|--------------|--------|-------|
| **6.0.3** | ✅ Verified | Recommended (tested) |
| 6.0.x | ⚠️ Untested | Should work |
| 5.9 | ⚠️ Deprecated | Type compatibility issues |
| 5.5-5.8 | ❌ Not supported | Breaking changes |

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **WSL2 (Ubuntu 22.04)** | ✅ Verified | Primary dev environment |
| macOS (ARM64) | ✅ Compatible | Not tested recently |
| macOS (x86_64) | ✅ Compatible | Not tested recently |
| Linux (Ubuntu 22.04) | ✅ Compatible | Native build |
| FreeBSD | ⚠️ Untested | Should work (POSIX) |
| Windows (native) | ❌ Not supported | Use WSL |

---

## Known Issues

### Swift 6.0.3 Migration

**Changes from 5.x:**
- Stricter type checking (fixed in ccc6b1a)
- Optional unwrapping required (fixed)
- Generic parameter inference (fixed)

**Resolved Issues:**
- ✅ `Instruction` vs `InstructionType` type mismatch
- ✅ `pthread_create` Optional handling
- ✅ Platform abstraction (`asm` removal)

### Build Warnings (Safe to Ignore)

```
warning: 'let' pattern has no effect; sub-pattern didn't bind any variables
warning: immutable value 'opcode' was never used
warning: result of call to 'write32' is unused
```

These are non-critical and do not affect functionality.

---

## Troubleshooting

### "swift: command not found"

**Cause:** Swift not in PATH  
**Fix:**
```bash
export PATH=/usr/local/swift/usr/bin:$PATH
# Add to ~/.bashrc for persistence
```

### "module cache path" error

**Cause:** Case-sensitive path mismatch (Windows FS)  
**Fix:**
```bash
cd risc
rm -rf .build
swift build -c release
```

### "cannot find 'asm' in scope"

**Cause:** Old code using inline assembly  
**Fix:** Already resolved in ccc6b1a commit

### Link errors

**Cause:** Missing system libraries  
**Fix:**
```bash
sudo apt-get install build-essential
```

---

## Performance Verification

### Test Command

```bash
./bin/risc-emulator kernel/kernel.bin --max-cycles 1000000 --memory 256
```

### Expected Results

```
Branch Predictor:
  Predictions: 176,020
  Correct: 175,856
  Accuracy: 99.9%

CPI: 1.0
Cycles: 1,000,000
Instructions: 1,000,000
```

**Benchmarks:**
- Build time: ~14s (WSL, release mode)
- Boot cycles: ~500K (kernel init)
- Branch prediction: 99.9% accuracy
- Memory accesses: ~1.4M per 1M cycles

---

## Development Environment

### Recommended Setup

```
OS: WSL2 + Ubuntu 22.04
Editor: VS Code + Swift extension
Shell: bash
Swift: 6.0.3
```

### VS Code Extensions

- Swift Language (swiftlang.swift-lang)
- RISC-V Support (optional)

---

**Maintained by:** Leenux Dev Team  
**Last Build:** 2026-02-14 14:30 KST  
**Commit:** ccc6b1a
