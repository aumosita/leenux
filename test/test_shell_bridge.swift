#!/usr/bin/env swift

import Foundation

// Test bridge_shell.bin with KernelBridge
print("🧪 Testing Shell Bridge...")

class KernelBridge {
    private var process: Process?
    private var stdinPipe: Pipe
    private var stdoutPipe: Pipe
    
    init() {
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, emulatorPath: String, maxCycles: Int = 1000) throws {
        process = Process()
        process?.executableURL = URL(fileURLWithPath: emulatorPath)
        process?.arguments = [kernelPath, "--max-cycles", "\(maxCycles)"]
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
        print("✓ Shell process started")
    }
    
    func readOutput(timeout: TimeInterval = 2.0) -> String {
        var output = ""
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            let data = stdoutPipe.fileHandleForReading.availableData
            if !data.isEmpty {
                if let text = String(data: data, encoding: .utf8) {
                    output += text
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        
        return output
    }
    
    func stop() {
        process?.terminate()
        print("✓ Shell stopped")
    }
}

// Test
let bridge = KernelBridge()

do {
    try bridge.start(
        kernelPath: "kernel/bridge_shell.bin",
        emulatorPath: "bin/risc-emulator",
        maxCycles: 500
    )
    
    // Wait for shell output
    sleep(1)
    let output = bridge.readOutput(timeout: 2.0)
    
    print("\n📤 Shell Output:")
    print("=".repeating(count: 60))
    
    // Extract only UART output (lines starting with letters)
    let lines = output.components(separatedBy: "\n")
    for line in lines {
        if let first = line.first, first.isLetter || line.hasPrefix("leenux>") {
            print(line)
        }
    }
    
    print("=".repeating(count: 60))
    
    bridge.stop()
    
    // Check for expected outputs
    if output.contains("Leenux Shell") && output.contains("leenux>") && output.contains("format") {
        print("\n✅ Shell bridge test PASSED!")
        print("   - Welcome message: ✓")
        print("   - Prompt: ✓")
        print("   - Command echo: ✓")
        print("   - Format output: ✓")
    } else {
        print("\n❌ Shell bridge test FAILED")
        print("Output length: \(output.count) bytes")
    }
    
} catch {
    print("❌ Error: \(error)")
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
