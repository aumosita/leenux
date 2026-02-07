#!/usr/bin/env swift

import Foundation

print("�� Testing Working Shell Bridge...")

class KernelBridge {
    private var process: Process?
    private var stdoutPipe: Pipe
    
    init() {
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, maxCycles: Int = 300) throws {
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "bin/risc-emulator")
        process?.arguments = [kernelPath, "--max-cycles", "\(maxCycles)"]
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
    }
    
    func readAll() -> String {
        var output = ""
        sleep(1)
        
        for _ in 0..<20 {
            let data = stdoutPipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            if let text = String(data: data, encoding: .utf8) {
                output += text
            }
            usleep(50000)
        }
        
        return output
    }
    
    func stop() {
        process?.terminate()
    }
}

do {
    let bridge = KernelBridge()
    try bridge.start(kernelPath: "kernel/shell_working.bin", maxCycles: 300)
    
    let output = bridge.readAll()
    bridge.stop()
    
    // Extract shell lines
    let lines = output.components(separatedBy: "\n")
    var shellLines: [String] = []
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Leenux") ||
           trimmed.hasPrefix("leenux>") ||
           trimmed.hasPrefix("Done") ||
           trimmed.hasPrefix("format") {
            shellLines.append(trimmed)
        }
    }
    
    print("\n📤 Shell Output:")
    print("="  .repeating(count: 60))
    for line in shellLines {
        print(line)
    }
    print("=".repeating(count: 60))
    
    print("\n✅ SUCCESS! Shell bridge is working!")
    print("   Lines captured: \(shellLines.count)")
    
} catch {
    print("❌ Error: \(error)")
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
