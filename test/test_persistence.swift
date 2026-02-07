
import Foundation

let emulatorPath = "./bin/risc-emulator"
let diskImagePath = "disk.img"

func runCommand(_ command: String) -> String {
    let process = Process()
    process.launchPath = "/bin/sh"
    process.arguments = ["-c", command]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

print("🧪 Starting Persistence Test...")

// 1. First Boot: Create a file
print("1️⃣  First Boot: Creating file 'hello.txt'...")
let createProcess = Process()
createProcess.launchPath = emulatorPath
createProcess.arguments = ["kernel/kernel.bin", "--max-cycles", "100000000", "--debug"] // Assuming kernel is the default or passed here
// We need to feed input to the emulator. 
// Ideally, the emulator accepts stdin.
// If not, we might need a more complex interaction or a specific test flag.

// Since our emulator reads from stdin, we can pipe commands.
let pipeIn1 = Pipe()
let pipeOut1 = Pipe()
createProcess.standardInput = pipeIn1
createProcess.standardOutput = pipeOut1
createProcess.launch()

let input1 = """
format
touch hello.txt
ls
shutdown

"""
pipeIn1.fileHandleForWriting.write(input1.data(using: .utf8)!)
// Give it some time to process
Thread.sleep(forTimeInterval: 10.0) 
// Close input to signal potentially correct end if shutdown command handles it
// pipeIn1.fileHandleForWriting.closeFile()

createProcess.terminate()
createProcess.waitUntilExit()

let output1 = String(data: pipeOut1.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
print("Output 1:\n\(output1)")


// 2. Second Boot: Check for file
print("2️⃣  Second Boot: Verifying file 'hello.txt'...")
let verifyProcess = Process()
verifyProcess.launchPath = emulatorPath
verifyProcess.arguments = ["kernel/kernel.bin", "--max-cycles", "100000000", "--debug"]

let pipeIn2 = Pipe()
let pipeOut2 = Pipe()
verifyProcess.standardInput = pipeIn2
verifyProcess.standardOutput = pipeOut2
verifyProcess.launch()

let input2 = """
ls
shutdown

"""
pipeIn2.fileHandleForWriting.write(input2.data(using: .utf8)!)
Thread.sleep(forTimeInterval: 10.0)
verifyProcess.terminate()
verifyProcess.waitUntilExit()

let output2 = String(data: pipeOut2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
print("Output 2:\n\(output2)")

if output2.contains("hello.txt") {
    print("✅ Persistence Test PASSED: 'hello.txt' found after reboot.")
} else {
    print("❌ Persistence Test FAILED: 'hello.txt' NOT found.")
}
