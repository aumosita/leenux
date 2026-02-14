#!/usr/bin/env swift

import Foundation

// Simple test of KernelBridge
print("🧪 Testing KernelBridge...")

class KernelBridge {
    private var process: Process?
    private var stdinPipe: Pipe
    private var stdoutPipe: Pipe
    
    init() {
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, emulatorPath: String) throws {
        process = Process()
        process?.executableURL = URL(fileURLWithPath: emulatorPath)
        process?.arguments = [kernelPath, "--max-cycles", "200"]
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
        print("✓ Process started")
    }
    
    func readOutput(timeout: TimeInterval = 1.0) -> String {
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
        print("✓ Process stopped")
    }
}

// Test
let bridge = KernelBridge()

do {
    try bridge.start(
        kernelPath: "kernel/bridge_test.bin",
        emulatorPath: "bin/risc-emulator"
    )
    
    // Wait and read output
    sleep(1)
    let output = bridge.readOutput(timeout: 2.0)
    
    print("📤 Output from kernel:")
    print(output)
    
    bridge.stop()
    
    if output.contains("Leenux") {
        print("✅ Bridge test PASSED!")
    } else {
        print("❌ Bridge test FAILED - no output")
    }
    
} catch {
    print("❌ Error: \(error)")
}
