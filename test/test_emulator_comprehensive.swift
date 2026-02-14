#!/usr/bin/env swift

import Foundation

// Comprehensive RISC-V Emulator Test Suite
print("🧪 RISC-V Emulator - Comprehensive Test Suite")
print("=" .repeating(count: 60))

class TestRunner {
    var passed = 0
    var failed = 0
    var tests: [(name: String, test: () -> Bool)] = []
    
    func add(_ name: String, test: @escaping () -> Bool) {
        tests.append((name, test))
    }
    
    func run() {
        for (name, test) in tests {
            print("\n🔍 Testing: \(name)")
            if test() {
                print("   ✅ PASS")
                passed += 1
            } else {
                print("   ❌ FAIL")
                failed += 1
            }
        }
        
        print("\n" + "=".repeating(count: 60))
        print("📊 Results: \(passed) passed, \(failed) failed")
        if failed == 0 {
            print("🎉 All tests passed!")
        }
    }
}

// Helper: Run emulator and capture output
func runEmulator(kernel: String, maxCycles: Int = 100) -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "bin/risc-emulator")
    process.arguments = [kernel, "--max-cycles", "\(maxCycles)"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return (output, process.terminationStatus)
    } catch {
        return ("Error: \(error)", -1)
    }
}

let runner = TestRunner()

// Test 1: Basic Execution
runner.add("Basic Execution - Simple UART output") {
    let (output, exitCode) = runEmulator(kernel: "kernel/uart_test_fixed.bin", maxCycles: 30)
    return output.contains("Hi!") && exitCode == 0
}

// Test 2: Shell Kernel
runner.add("Shell Kernel - Welcome message") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    return output.contains("Leenux Shell v0.1")
}

// Test 3: Shell Prompt
runner.add("Shell Kernel - Prompt generation") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    return output.contains("leenux>")
}

// Test 4: Command Echo
runner.add("Shell Kernel - Command echo") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    return output.contains("format")
}

// Test 5: Output Quality
runner.add("Shell Kernel - Output completeness") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    return output.contains("Done!")
}

// Test 6: MMIO Registration
runner.add("MMIO Devices - UART registration") {
    let (output, _) = runEmulator(kernel: "kernel/uart_test_fixed.bin", maxCycles: 10)
    return output.contains("UART at 0x10000000")
}

// Test 7: Multi-cycle execution
runner.add("Execution - Multiple iterations") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    // Should see multiple prompts
    let promptCount = output.components(separatedBy: "leenux>").count - 1
    return promptCount >= 2
}

// Test 8: Memory Bus
runner.add("Memory Bus - Write operations") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 100)
    return output.contains("Writes:")
}

// Test 9: No Crashes
runner.add("Stability - No runtime errors") {
    let (output, exitCode) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 500)
    return exitCode == 0 && !output.contains("error") && !output.contains("Error")
}

// Test 10: Binary Size Validation
runner.add("Binary Validation - Correct assembly") {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: "kernel/shell_working.bin"),
          let size = attrs[.size] as? UInt64 else {
        return false
    }
    // Should be 332 bytes
    return size == 332
}

// Test 11: UART Test Binary
runner.add("Binary Validation - UART test size") {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: "kernel/uart_test_fixed.bin"),
          let size = attrs[.size] as? UInt64 else {
        return false
    }
    // Should be 44 bytes
    return size == 44
}

// Test 12: Emulator Exists
runner.add("Environment - Emulator binary exists") {
    return FileManager.default.fileExists(atPath: "bin/risc-emulator")
}

// Test 13: Kernel Files Exist
runner.add("Environment - Kernel files exist") {
    let fm = FileManager.default
    return fm.fileExists(atPath: "kernel/shell_working.bin") &&
           fm.fileExists(atPath: "kernel/uart_test_fixed.bin")
}

// Test 14: Output Parsing
runner.add("Output Parsing - Clean extraction") {
    let (output, _) = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 200)
    let lines = output.components(separatedBy: "\n")
    let shellLines = lines.filter { line in
        line.contains("Leenux") || line.contains("leenux>") || line.contains("format")
    }
    return shellLines.count >= 5
}

// Test 15: Performance
runner.add("Performance - Execution speed") {
    let start = Date()
    _ = runEmulator(kernel: "kernel/shell_working.bin", maxCycles: 300)
    let duration = Date().timeIntervalSince(start)
    // Should complete in less than 5 seconds
    return duration < 5.0
}

// Run all tests
runner.run()

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
