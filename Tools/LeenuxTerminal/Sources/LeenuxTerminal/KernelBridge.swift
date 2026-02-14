import Foundation

/// Bridge between Swift Terminal and RISC-V Kernel
/// Manages Process/Pipe communication with the emulator
class KernelBridge {
    private var process: Process?
    private var stdinPipe: Pipe
    private var stdoutPipe: Pipe
    private var stderrPipe: Pipe
    private var outputBuffer: String = ""
    private var isRunning = false
    
    init() {
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
        stderrPipe = Pipe()
    }
    
    /// Start the RISC-V emulator with kernel
    func start(kernelPath: String = "kernel/kernel.bin", 
               emulatorPath: String = "bin/risc-emulator") throws {
        process = Process()
        
        // Build absolute paths
        let currentDir = FileManager.default.currentDirectoryPath
        let absEmulatorPath = currentDir + "/" + emulatorPath
        let absKernelPath = currentDir + "/" + kernelPath
        
        process?.executableURL = URL(fileURLWithPath: absEmulatorPath)
        process?.arguments = [
            absKernelPath,
            "--memory", "256",
            "--max-cycles", "1000000"
        ]
        
        process?.standardInput = stdinPipe
        process?.standardOutput = stdoutPipe
        process?.standardError = stderrPipe
        
        // Read stdout in background
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                self?.outputBuffer += output
            }
        }
        
        // Read stderr in background (for debug)
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                print("Kernel stderr: \(error)")
            }
        }
        
        try process?.run()
        isRunning = true
        
        print("✓ Kernel bridge started")
    }
    
    /// Execute a command in the kernel
    func execute(_ command: String, timeout: TimeInterval = 0.5) -> [String] {
        guard isRunning else {
            return ["Error: Kernel not running"]
        }
        
        outputBuffer = ""
        
        // Send command to kernel stdin
        let data = "\(command)\n".data(using: .utf8)!
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            return ["Error: Failed to send command: \(error)"]
        }
        
        // Wait for output with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && outputBuffer.isEmpty {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        
        // Parse output
        let lines = outputBuffer.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return lines.isEmpty ? ["(no output)"] : lines
    }
    
    /// Stop the emulator
    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
        print("✓ Kernel bridge stopped")
    }
    
    deinit {
        stop()
    }
}
