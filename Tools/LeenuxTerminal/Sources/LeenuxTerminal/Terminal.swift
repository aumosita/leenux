import CSDL2
import Foundation

class Terminal {
    let width = 1024
    let height = 768
    
    var window: OpaquePointer?
    var renderer: OpaquePointer?
    var texture: OpaquePointer?
    var pixels: UnsafeMutablePointer<UInt8>
    
    var commandLine = ""
    var history: [String] = []  // Display history
    var commandHistory: [String] = []  // Executed commands only
    var historyIndex = -1  // Current position in command history
    var scrollOffset = 0
    var maxVisibleLines = 23
    var cursorVisible = true
    var lastBlink = Date()
    
    let colorBG: UInt32 = 0x00F5F5DC
    let colorText: UInt32 = 0x00000000
    let colorPrompt: UInt32 = 0x000066CC
    let colorError: UInt32 = 0x00CC0000  // Red
    let colorSuccess: UInt32 = 0x0000AA00  // Green
    
    var kernelBridge: KernelBridge?
    var useBridge = true  // Enable real kernel mode
    
    let koreanRenderer = KoreanRenderer()
    
    init() {
        // Initialize Kernel Bridge
        if useBridge {
            kernelBridge = KernelBridge()
            do {
                // Use the working shell kernel
                try kernelBridge?.start(kernelPath: "kernel/kernel.bin", emulatorPath: "bin/risc-emulator")
                print("✓ Kernel Bridge connected")
            } catch {
                print("❌ Failed to start kernel bridge: \(error)")
                useBridge = false
            }
        }
        
        // Allocate pixel buffer
        pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        
        // Create window
        window = SDL_CreateWindow(
            "Leenux Terminal - Swift (Kernel Mode)",
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(width),
            Int32(height),
            SDL_WINDOW_SHOWN.rawValue
        )
        
        guard window != nil else {
            fatalError("Failed to create window: \(String(cString: SDL_GetError()))")
        }
        
        // Create renderer
        renderer = SDL_CreateRenderer(
            window,
            -1,
            SDL_RENDERER_ACCELERATED.rawValue | SDL_RENDERER_PRESENTVSYNC.rawValue
        )
        
        guard renderer != nil else {
            fatalError("Failed to create renderer: \(String(cString: SDL_GetError()))")
        }
        
        // Create texture
        texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_RGBA32.rawValue,
            Int32(SDL_TEXTUREACCESS_STREAMING.rawValue),
            Int32(width),
            Int32(height)
        )
        
        guard texture != nil else {
            fatalError("Failed to create texture: \(String(cString: SDL_GetError()))")
        }
        
        print("✓ SDL2 window created")
        if useBridge {
            print("✓ Connected to RISC-V Kernel")
        }
        
        // Enable text input
        SDL_StartTextInput()
    }
    
    func run() {
        var running = true
        var event = SDL_Event()
        
        while running {
            while SDL_PollEvent(&event) != 0 {
                let eventType = SDL_EventType(rawValue: event.type)
                
                switch eventType {
                case SDL_QUIT:
                    running = false
                    
                case SDL_TEXTINPUT:
                    handleTextInput(&event)
                    
                case SDL_KEYDOWN:
                    running = handleKeyDown(&event)
                    
                default:
                    break
                }
            }
            
            // Update cursor blink
            updateBlink()
            
            // Render
            render()
            
            // Update display
            SDL_UpdateTexture(
                texture,
                nil,
                pixels,
                Int32(width * 4)
            )
            
            SDL_RenderClear(renderer)
            SDL_RenderCopy(renderer, texture, nil, nil)
            SDL_RenderPresent(renderer)
            
            SDL_Delay(16) // ~60 FPS
        }
    }
    
    func handleTextInput(_ event: inout SDL_Event) {
        // SDL_Event.text.text is a fixed-size C array
        var textBuffer = event.text.text
        
        withUnsafePointer(to: &textBuffer) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 32) { cstr in
                if let text = String(cString: cstr, encoding: .utf8) {
                    // Only trim control characters, keep spaces!
                    let cleaned = text.trimmingCharacters(in: .controlCharacters)
                    
                    if !cleaned.isEmpty && commandLine.count < 60 {
                        commandLine += cleaned
                    }
                }
            }
        }
    }
    
    func handleKeyDown(_ event: inout SDL_Event) -> Bool {
        let key = event.key.keysym.sym
        
        switch Int32(key) {
        case Int32(SDLK_RETURN.rawValue):
            executeCommand()
            
        case Int32(SDLK_BACKSPACE.rawValue):
            if !commandLine.isEmpty {
                commandLine.removeLast()
            }
            
        case Int32(SDLK_UP.rawValue):
            // Navigate up in history
            if !commandHistory.isEmpty {
                if historyIndex == -1 {
                    historyIndex = commandHistory.count - 1
                } else if historyIndex > 0 {
                    historyIndex -= 1
                }
                if historyIndex >= 0 {
                    commandLine = commandHistory[historyIndex]
                }
            }
            
        case Int32(SDLK_DOWN.rawValue):
            // Navigate down in history
            if historyIndex != -1 {
                historyIndex += 1
                if historyIndex >= commandHistory.count {
                    historyIndex = -1
                    commandLine = ""
                } else {
                    commandLine = commandHistory[historyIndex]
                }
            }
            
        case Int32(SDLK_TAB.rawValue):
            // Tab completion
            autocomplete()
            
        default:
            break
        }
        
        return true
    }
    
    func autocomplete() {
        let commands = ["help", "echo", "clear", "uname", "ls", "cat", "pwd", 
                       "cd", "free", "malloc", "memtest", "format", "df", 
                       "touch", "mkdir", "halt", "exit", "quit"]
        
        for cmd in commands {
            if cmd.hasPrefix(commandLine) && commandLine != cmd {
                commandLine = cmd
                break
            }
        }
    }
    
    func executeCommand() {
        guard !commandLine.isEmpty else { return }
        
        // Add to command history
        commandHistory.append(commandLine)
        if commandHistory.count > 50 {
            commandHistory.removeFirst()
        }
        historyIndex = -1  // Reset history navigation
        
        history.append("leenux> \(commandLine)")
        
        var output: [String] = []
        
        if useBridge, let bridge = kernelBridge {
            output = bridge.execute(commandLine)
        } else {
            // Fallback to mock processor
            let processor = CommandProcessor()
            output = processor.execute(commandLine)
        }
        
        // Check for halt signal
        if commandLine == "halt" || commandLine == "exit" || output.first == "__HALT__" {
            exit(0)
        }
        
        // Determine output color based on content
        for line in output {
            let color: UInt32
            if line.contains("error") || line.contains("Error") || 
               line.contains("not found") || line.contains("Unknown") {
                color = colorError  // Red for errors
            } else if line.contains("Created") || line.contains("Done") || 
                      line.contains("OK") || line.contains("passed") {
                color = colorSuccess  // Green for success
            } else {
                color = colorText  // Default
            }
            
            // Store line with color metadata (we'll handle this in rendering)
            history.append(line)
        }
        
        commandLine = ""
        
        // Keep only last 100 lines
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
    }
    
    func updateBlink() {
        let now = Date()
        if now.timeIntervalSince(lastBlink) > 0.5 {
            cursorVisible.toggle()
            lastBlink = now
        }
    }
    
    func render() {
        // Clear screen with beige
        clearScreen(colorBG)
        
        // Calculate visible range with scroll
        let totalLines = history.count + 1  // +1 for current command line
        let startIdx = max(0, totalLines - maxVisibleLines - scrollOffset)
        let endIdx = min(history.count, startIdx + maxVisibleLines)
        
        // Render visible history lines
        var y = 10
        for i in startIdx..<endIdx {
            drawString(history[i], x: 10, y: y, color: colorText)
            y += 12
        }
        
        // Draw prompt
        drawString("leenux> ", x: 10, y: y, color: colorPrompt)
        
        // Draw command line
        if !commandLine.isEmpty {
            drawString(commandLine, x: 10 + 8 * 6, y: y, color: colorText)
        }
        
        // Draw cursor
        if cursorVisible {
            var cursorX = 10 + 8 * 6
            for char in commandLine {
                cursorX += char.isASCII ? 6 : 14
            }
            
            for dy in 0..<12 {
                for dx in 0..<2 {
                    setPixel(cursorX + dx, y + dy, colorText)
                }
            }
        }
    }
    
    func drawString(_ text: String, x: Int, y: Int, color: UInt32) {
        var cx = x
        for char in text {
            if char.isASCII {
                drawASCIIChar(char, x: cx, y: y, color: color)
                cx += 6
            } else {
                // Korean or other Unicode characters
                drawKoreanChar(char, x: cx, y: y, color: color)
                cx += 14
            }
        }
    }
    
    func drawASCIIChar(_ char: Character, x: Int, y: Int, color: UInt32) {
        guard let bitmap = Font5x8.bitmap(for: char) else { return }
        
        for row in 0..<8 {
            let byte = bitmap[row]
            for bit in 0..<5 {
                if (byte & (0x10 >> bit)) != 0 {
                    setPixel(x + bit, y + row, color)
                }
            }
        }
    }
    
    func drawKoreanChar(_ char: Character, x: Int, y: Int, color: UInt32) {
        guard let charPixels = koreanRenderer.renderCharacter(char) else {
            // Fallback: draw placeholder for unsupported characters
            return
        }
        
        // Draw 16x16 character from CoreText
        for dy in 0..<16 {
            for dx in 0..<16 {
                let idx = (dy * 20 + dx) * 4
                guard idx + 2 < charPixels.count else { continue }
                
                let r = charPixels[idx]
                let g = charPixels[idx + 1]
                let b = charPixels[idx + 2]
                
                // Skip beige background pixels (245, 245, 220)
                if r == 245 && g == 245 && b == 220 { continue }
                
                let px = x + dx
                let py = y + dy
                setPixel(px, py, UInt32(b) | (UInt32(g) << 8) | (UInt32(r) << 16) | 0xFF000000)
            }
        }
    }
    
    func clearScreen(_ color: UInt32) {
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            pixels[i] = UInt8(color & 0xFF)
            pixels[i + 1] = UInt8((color >> 8) & 0xFF)
            pixels[i + 2] = UInt8((color >> 16) & 0xFF)
            pixels[i + 3] = 0xFF
        }
    }
    
    func setPixel(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let offset = (y * width + x) * 4
        pixels[offset] = UInt8(color & 0xFF)
        pixels[offset + 1] = UInt8((color >> 8) & 0xFF)
        pixels[offset + 2] = UInt8((color >> 16) & 0xFF)
        pixels[offset + 3] = UInt8((color >> 24) & 0xFF)
    }
    
    deinit {
        SDL_DestroyTexture(texture)
        SDL_DestroyRenderer(renderer)
        SDL_DestroyWindow(window)
        pixels.deallocate()
    }
}
