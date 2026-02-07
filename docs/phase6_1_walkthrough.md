# Phase 6.1: Terminal-Kernel Bridge - Walkthrough

## 🎯 Objective
Connect Swift Terminal to RISC-V Kernel via Process/Pipe for real OS functionality

---

## 🔍 Journey

### Discovery: RISC Emulator Source
- Found `risc/` folder with Swift Package
- Identified `UARTDevice.swift` for stdout output
- **Architecture:** SharedMemory → findDevice → UARTDevice.write8

### Challenge 1: UART Not Routing
**Problem:** UART writes not reaching UARTDevice

**Investigation:**
```bash
# Debug output showed:
[Core 0] STORE: addr=0x10000, val=72    # ❌ Wrong!
# Should be:
[Core 0] STORE: addr=0x10000000         # ✅ Correct
```

**Root Cause:** Assembler bug with `li` pseudo-instruction
```asm
# Original (BROKEN):
li t0, 0x10000000      # Assembled as 0x10000!

# Fixed:
lui t0, 0x10000        # Correct: 0x10000 << 12 = 0x10000000
```

### Breakthrough: UART Working
```
./bin/risc-emulator kernel/uart_test_fixed.bin --max-cycles 30

Output:
Hi!
```

**Proof:**
- UART writes to 0x10000000 ✅
- SharedMemory routes to device ✅  
- UARTDevice prints to stdout ✅

### Success: Swift Bridge
```swift
// KernelBridge captures emulator stdout
📤 Output from kernel:
Hi!
```

**Test Result:**
- Output captured: 1466 bytes
- Contains: "Hi!"
- Bridge working ✅

---

## 📁 Files Changed

### Created
| File                       | Purpose                         |
| -------------------------- | ------------------------------- |
| `KernelBridge.swift`       | Process/Pipe bridge to emulator |
| `kernel/uart_test_fixed.s` | Test kernel with fixed address  |
| `test_bridge_uart.swift`   | Validation test                 |

### Modified
| File                 | Change                                        |
| -------------------- | --------------------------------------------- |
| `UARTDevice.swift`   | Direct stdout output (removed callback check) |
| `SharedMemory.swift` | Added/removed debug output                    |

---

## ✅ What Works

1. **Emulator stdout** - UART writes appear in stdout
2. **Swift bridge** - Process/Pipe captures output
3. **MMIO routing** - Address 0x10000000 → UARTDevice

---

## 🚧 Remaining Work

### 1. Clean Build (30min)
- Remove SharedMemory debug output ✅
- Release build
- Test clean output

### 2. Full Shell Kernel (2h)
Create `kernel/shell.s` with:
- Command parser
- `format` - Initialize disk
- `ls` - List files
- `touch` - Create file
- `mkdir` - Create directory
- `cat` - Read file

### 3. Terminal Integration (1h)
```swift
// In Terminal.swift
func executeCommand() {
    let output = kernelBridge.execute(commandLine)
    history.append(contentsOf: output)
}
```

### 4. Final Testing (30min)
- All 15 commands
- Korean input with kernel
- Demo preparation

---

## 🎓 Lessons Learned

### Technical
1. **RISC-V Assembler:** `li` pseudo-instruction limitations
   - Use `lui` for addresses > 12 bits
   
2. **MMIO Architecture:** SharedMemory → MMIODevice abstraction
   - Clean separation of concerns
   - Thread-safe implementation

3. **Process/Pipe:** Swift can capture stdout from subprocesses
   - `availableData` is non-blocking
   - Need timeouts for async reads

### Debugging
1. **Add debug output strategically** - SharedMemory trace was key
2. **Use --debug flag** - Shows actual STORE addresses
3. **Verify assumptions** - "It should work" ≠ "It does work"

---

## 📊 Metrics

| Metric             | Value                          |
| ------------------ | ------------------------------ |
| **Time Spent**     | ~3 hours                       |
| **Bugs Found**     | 1 (assembler address encoding) |
| **Files Created**  | 3                              |
| **Files Modified** | 2                              |
| **LOC Added**      | ~200                           |

---

## 🚀 Next Session

**Priority:**
1. Build release emulator without debug output
2. Create full shell kernel with real commands
3. Integrate KernelBridge into Terminal
4. Test all commands end-to-end

**Goal:** Fully functional Terminal ↔ Kernel communication!

---

**Status:** ✅ Phase 6.1 Core Complete
**Next:** Phase 6.2 Full Shell Implementation
