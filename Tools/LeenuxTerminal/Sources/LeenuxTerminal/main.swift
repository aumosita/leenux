import CSDL2

// Main entry point
print("🖥️  Leenux Terminal (Swift)")
print("=" + String(repeating: "=", count: 49))

// Initialize SDL2
guard SDL_Init(SDL_INIT_VIDEO) == 0 else {
    print("SDL2 Error: \(String(cString: SDL_GetError()))")
    exit(1)
}

defer { SDL_Quit() }

// Create and run terminal
let terminal = Terminal()
terminal.run()

print("\nTerminal closed.")

