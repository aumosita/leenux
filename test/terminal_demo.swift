import CSDL2
import Foundation

// Simple Terminal Demo showing kernel output
class TerminalDemo {
    let width = 1024
    let height = 768
    
    var window: OpaquePointer?
    var renderer: OpaquePointer?
    
    // Shell output to display
    var outputLines: [String] = []
    var scrollOffset = 0
    
    let colorBG: UInt32 = 0x00F5F5DC  // Beige
    let colorText: UInt32 = 0x00000000  // Black
    let colorPrompt: UInt32 = 0x000066CC  // Blue
    
    init() {
        window = SDL_CreateWindow(
            "Leenux Terminal Demo",
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(width),
            Int32(height),
            SDL_WINDOW_SHOWN.rawValue
        )
        
        guard window != nil else {
            fatalError("Failed to create window")
        }
        
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED.rawValue)
        
        guard renderer != nil else {
            fatalError("Failed to create renderer")
        }
        
        print("✓ Terminal Demo ready")
        
        // Load shell output
        loadShellOutput()
    }
    
    func loadShellOutput() {
        let bridge = KernelBridge()
        
        do {
            try bridge.start(kernelPath: "../../../kernel/shell_working.bin", maxCycles: 300)
            let output = bridge.readAll()
            bridge.stop()
            
            // Parse shell lines
            output.components(separatedBy: "\n").forEach { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.hasPrefix("📂") && !trimmed.hasPrefix("🔌") {
                    outputLines.append(trimmed)
                }
            }
            
            print("✓ Loaded \(outputLines.count) lines from kernel")
            
        } catch {
            outputLines = ["Error: \(error)"]
        }
    }
    
    func run() {
        var running = true
        var event = SDL_Event()
        
        while running {
            while SDL_PollEvent(&event) != 0 {
                if SDL_EventType(rawValue: event.type) == SDL_QUIT {
                    running = false
                }
            }
            
            render()
            SDL_Delay(16)  // ~60 FPS
        }
    }
    
    func render() {
        // Clear background
        SDL_SetRenderDrawColor(renderer, 245, 245, 220, 255)
        SDL_RenderClear(renderer)
        
        // Draw title
        drawText(x: 20, y: 20, text: "🎉 Leenux Terminal - Kernel Bridge Demo", color: colorPrompt)
        drawText(x: 20, y: 50, text: "=" .repeating(count: 60), color: colorText)
        
        // Draw shell output
        var y = 90
        for (index, line) in outputLines.enumerated() {
            if index >= scrollOffset && y < height - 50 {
                let color: UInt32 = line.hasPrefix("leenux>") ? colorPrompt : colorText
                drawText(x: 40, y: y, text: line, color: color)
                y += 25
            }
        }
        
        // Draw footer
        drawText(x: 20, y: height - 30, text: "Press Q to quit", color: colorText)
        
        SDL_RenderPresent(renderer)
    }
    
    func drawText(x: Int, y: Int, text: String, color: UInt32) {
        // Simple pixel-based text (10x16 font)
        let r = UInt8((color >> 16) & 0xFF)
        let g = UInt8((color >> 8) & 0xFF)
        let b = UInt8(color & 0xFF)
        
        SDL_SetRenderDrawColor(renderer, r, g, b, 255)
        
        for (i, char) in text.enumerated() {
            let charX = x + i * 10
            // Draw simple rectangle for each character (placeholder)
            var rect = SDL_Rect(x: Int32(charX), y: Int32(y), w: 8, h: 14)
            if char != " " {
                SDL_RenderFillRect(renderer, &rect)
            }
        }
    }
    
    deinit {
        SDL_DestroyRenderer(renderer)
        SDL_DestroyWindow(window)
    }
}

class KernelBridge {
    private var process: Process?
    private var stdoutPipe: Pipe
    
    init() {
        stdoutPipe = Pipe()
    }
    
    func start(kernelPath: String, maxCycles: Int) throws {
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

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// Main
SDL_Init(SDL_INIT_VIDEO)
let demo = TerminalDemo()
demo.run()
SDL_Quit()
