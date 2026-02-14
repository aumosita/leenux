#!/usr/bin/env swift

import Foundation

print("🧪 Testing Inline Shell Bridge...")

let bridge = KernelBridge()

class KernelBridge {
    private var process: Process?
    private var stdoutPipe: Pipe
    
    init() {
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, emulatorPath: String, maxCycles: Int = 500) throws {
        process = Process()
        process?.executableURL = URL(fileURLWithPath: emulatorPath)
        process?.arguments = [kernelPath, "--max-cycles", "\(maxCycles)"]
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
        print("✓ Shell started")
    }
    
    func readAll() -> String {
        var output = ""
        sleep(1)
        
        // Read all available data
        for _ in 0..<20 {
            let data = stdoutPipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            if let text = String(data: data, encoding: .utf8) {
                output += text
            }
            usleep(50000) // 50ms
        }
        
        return output
    }
    
    func stop() {
        process?.terminate()
    }
}

do {
    try bridge.start(
        kernelPath: "kernel/shell_inline.bin",
        emulatorPath: "bin/risc-emulator"
    )
    
    let output = bridge.readAll()
    bridge.stop()
    
    print("\n📤 Shell Output (UART only):")
    print("="  .repeating(count: 60))
    
    // Extract shell output
    let lines = output.components(separatedBy: "\n")
    var shellOutput: [String] = []
    
    for line in lines {
        // Only show lines that look like shell output
        if line.hasPrefix("Leenux") ||
           line.hasPrefix("leenux>") ||
           line.hasPrefix("format") ||
           line.hasPrefix("Done") ||
           (line.first?.isLetter == true && line.count < 50) {
            shellOutput.append(line)
        }
    }
    
    for line in shellOutput {
        print(line)
    }
    
    print("=".repeating(count: 60))
    
    // Validate
    let hasWelcome = shellOutput.contains(where: { $0.contains("Leenux Shell") })
    let hasPrompt = shellOutput.contains(where: { $0.contains("leenux>") })
    let hasFormat = shellOutput.contains(where: { $0.contains("format") })
    let hasDone = shellOutput.contains(where: { $0.contains("Done") })
    
    print("\n✅ Checks:")
    print("   Welcome: \(hasWelcome ? "✓" : "✗")")
    print("   Prompt: \(hasPrompt ? "✓" : "✗")")
    print("   Command: \(hasFormat ? "✓" : "✗")")
    print("   Output: \(hasDone ? "✓" : "✗")")
    
    if hasWelcome && hasPrompt && hasFormat && hasDone {
        print("\n🎉 Shell bridge WORKING!")
    } else {
        print("\n⚠️  Partial success - some elements missing")
    }
    
} catch {
    print("❌ Error: \(error)")
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
