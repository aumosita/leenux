#!/usr/bin/env swift

import Foundation

// Test KernelBridge with uart_test_fixed.bin
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
        process?.arguments = [kernelPath, "--max-cycles", "100"]
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
        print("✓ Process started")
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
        print("✓ Process stopped")
    }
}

// Test
let bridge = KernelBridge()

do {
    try bridge.start(
        kernelPath: "kernel/uart_test_fixed.bin",
        emulatorPath: "bin/risc-emulator"
    )
    
    // Wait and read output
    sleep(1)
    let output = bridge.readOutput(timeout: 2.0)
    
    print("📤 Output from kernel:")
    print("---")
    print(output)
    print("---")
    
    bridge.stop()
    
    if output.contains("Hi!") {
        print("✅ Bridge test PASSED! 'Hi!' detected in output!")
    } else {
        print("❌ Bridge test FAILED - 'Hi!' not found")
        print("Output length: \(output.count) bytes")
    }
    
} catch {
    print("❌ Error: \(error)")
}
