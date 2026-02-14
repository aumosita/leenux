import Foundation

// Test Harness for Multitasking
let kernelPath = "kernel/kernel.bin"
let emulatorPath = "bin/risc-emulator"
let maxCycles = 5000000 // Run longer to see dot outputs

print("🧪 Testing Multitasking (Spawn)...")

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

// Helper to write command
func sendCommand(_ cmd: String) {
    if let data = (cmd + "\n").data(using: .utf8) {
        pipeIn.fileHandleForWriting.write(data)
        // Give it time to process
        Thread.sleep(forTimeInterval: 0.5)
    }
}

// 1. Wait for boot (Sleep)
Thread.sleep(forTimeInterval: 2.0)

// 2. Send 'spawn'
print("   Sending 'spawn' command...")
sendCommand("spawn")

// 3. Wait and observe output
Thread.sleep(forTimeInterval: 5.0)

// 4. Send 'ls' to see if shell is still responsive
print("   Sending 'ls' command...")
sendCommand("ls")

Thread.sleep(forTimeInterval: 1.0)

process.terminate()

// Analyze Output
let data = pipeOut.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: data, encoding: .utf8) {
    print("\n--- Emulator Output ---\n\(output)\n-----------------------")
    
    var passed = true
    
    if output.contains("Background task spawned") {
        print("   ✅ Spawn success message received")
    } else {
        print("   ❌ Missing spawn success message")
        passed = false
    }
    
    if output.contains(".") {
        print("   ✅ Background task output (.) detected")
    } else {
        print("   ❌ Missing background task output")
        passed = false
    }
    
    if output.contains("TYPE") && output.contains("NAME") {
        print("   ✅ Shell is still responsive (ls worked)")
    } else {
        print("   ❌ Shell seems unresponsive")
        passed = false
    }
    
    if passed {
        print("\n✅ Multitasking Test PASSED")
        exit(0)
    } else {
        print("\n❌ Multitasking Test FAILED")
        exit(1)
    }
} else {
    print("❌ No output captured")
    exit(1)
}
