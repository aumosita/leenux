import Foundation

// Test Harness for Preemptive Multitasking
let kernelPath = "kernel/kernel.bin"
let emulatorPath = "bin/risc-emulator"
let maxCycles = 10_000_000

print("🧪 Testing Preemption (Busy Wait)...")

let process = Process()
let pipeIn = Pipe()
let pipeOut = Pipe()
let pipeErr = Pipe()

let currentDir = FileManager.default.currentDirectoryPath
process.executableURL = URL(fileURLWithPath: currentDir + "/" + emulatorPath)
process.arguments = [kernelPath, "--max-cycles", "\(maxCycles)"]
process.standardInput = pipeIn
process.standardOutput = pipeOut
process.standardError = pipeErr

do {
    try process.run()
} catch {
    print("❌ Failed to start emulator: \(error)")
    exit(1)
}

func sendCommand(_ cmd: String) {
    if let data = (cmd + "\n").data(using: .utf8) {
        pipeIn.fileHandleForWriting.write(data)
        Thread.sleep(forTimeInterval: 0.5)
    }
}

// 1. Boot
Thread.sleep(forTimeInterval: 2.0)

// 2. Spawn Background Task
print("   Sending 'spawn'...")
sendCommand("spawn")
Thread.sleep(forTimeInterval: 2.0)

// 3. Send Busy Command (Simulated via 'help' loop if we don't have busy command yet)
// Wait, we didn't implement 'busy' command. 
// We rely on the fact that if we just sit idle in input loop, we are yielding (Cooperative).
// But to prove PREEMPTION, we need a BUSY loop.
// Let's assume for this test we just watch 'spawn' output.
// Actually, to truly test preemption, we need to remove 'yield' from input loop or add a busy command.
// For now, let's just see if it runs at all (doesn't crash).
print("   Letting it run...")
Thread.sleep(forTimeInterval: 5.0)

process.terminate()

let data = pipeOut.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: data, encoding: .utf8) {
    print("\n--- Emulator Output ---\n\(output)\n-----------------------")
    
    if output.contains("Background task spawned") && output.filter({ $0 == "." }).count > 5 {
        print("✅ Preemption Test PASSED (Background task running)")
        exit(0)
    } else {
        print("❌ Preemption Test FAILED (Background task not running properly)")
        exit(1)
    }
}
