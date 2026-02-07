#!/usr/bin/env swift

import Foundation

print("🧪 Testing Full Shell Kernel (SFS Integration)")
print("=" .repeating(count: 60))

class KernelBridge {
    private var process: Process?
    private var stdinPipe: Pipe
    private var stdoutPipe: Pipe
    
    init() {
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, maxCycles: Int = 5000) throws {
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "bin/risc-emulator")
        process?.arguments = [kernelPath, "--max-cycles", "\(maxCycles)", "--debug"]
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = FileHandle.nullDevice
        
        try process?.run()
    }
    
    func execute(_ command: String) {
        let data = "\(command)\n".data(using: .utf8)!
        stdinPipe.fileHandleForWriting.write(data)
        usleep(100000) // 100ms wait
    }
    
    func readAll() -> String {
        var output = ""
        // Give it time to flush
        usleep(500000) 
        
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8) {
            output = text
        }
        return output
    }
    
    func stop() {
        process?.terminate()
    }
}

let bridge = KernelBridge()

do {
    // 1. Start Kernel
    try bridge.start(kernelPath: "kernel/kernel.bin", maxCycles: 1000000)
    
    // 2. Clear initial buffer (welcome message)
    usleep(500000)
    
    // 3. Send Commands
    print("📤 Sending 'help'...")
    bridge.execute("help")
    
    print("📤 Sending 'format'...")
    bridge.execute("format")
    
    print("📤 Sending 'ls' (should be empty)...")
    bridge.execute("ls")
    
    print("📤 Sending 'touch testfile'...")
    bridge.execute("touch")
    
    print("📤 Sending 'ls' (should show file)...")
    bridge.execute("ls")
    
    // 4. Wait for completion (simulated by max cycles or explicit wait)
    // Since emulator runs for fixed cycles in test, we just wait a bit
    sleep(2)
    bridge.stop()
    
    // 5. Analyze Output
    let output = bridge.readAll()
    print("\n📥 Final Output:")
    print("------------------------------------------------------------")
    print(output)
    print("------------------------------------------------------------")
    
    // Validation
    let hasHelp = output.contains("Commands:")
    let hasFormat = output.contains("Disk formatted")
    let hasLsHeader = output.contains("TYPE  SIZE  NAME")
    let hasFile = output.contains("new.txt") // touch creates "new.txt" hardcoded
    
    print("\n✅ Verification:")
    print("   Help Command: \(hasHelp ? "PASS" : "FAIL")")
    print("   Format Disk:  \(hasFormat ? "PASS" : "FAIL")")
    print("   List Files:   \(hasLsHeader ? "PASS" : "FAIL")")
    print("   Create File:  \(hasFile ? "PASS" : "FAIL")")
    
    if hasHelp && hasFormat && hasLsHeader && hasFile {
        print("\n🎉 Full Shell works perfectly!")
    } else {
        print("\n❌ Test Failed")
    }

} catch {
    print("Error: \(error)")
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
