struct CommandProcessor {
    func execute(_ command: String) -> [String] {
        let parts = command.split(separator: " ", maxSplits: 1)
        guard let cmd = parts.first?.lowercased() else { return [] }
        
        let args = parts.count > 1 ? String(parts[1]) : ""
        
        switch cmd {
        case "halt", "exit", "quit":
            return ["__HALT__"]  // Special signal to exit
            
        case "echo":
            return [args]
            
        case "clear":
            return [] // Will be handled specially
            
        case "help":
            return [
                "Available commands:",
                "  echo <text>  - Print text",
                "  clear        - Clear screen",
                "  help         - Show this help",
                "  uname        - System information",
                "  ls [dir]     - List directory",
                "  cat <file>   - Show file content",
                "  pwd          - Current directory",
                "  cd <dir>     - Change directory",
                "  free         - Memory usage",
                "  malloc <n>   - Test allocation",
                "  memtest      - Test allocator",
                "  format       - Format disk",
                "  df           - Disk free space",
                "  touch <file> - Create file",
                "  mkdir <dir>  - Create directory"
            ]
            
        case "uname":
            return [
                "Leenux OS v0.3 (RISC-V RV64I)",
                "Kernel: Bare-metal",
                "RAM: 256 MB"
            ]
            
        case "ls":
            if args.isEmpty {
                return ["dev", "proc", "etc"]
            } else if args == "/dev" {
                return ["null", "fb"]
            } else if args == "/proc" {
                return ["meminfo", "cpuinfo"]
            } else if args == "/etc" {
                return ["version"]
            }
            return []
            
        case "cat":
            if args == "/proc/meminfo" {
                return [
                    "MemTotal: 256 MB",
                    "MemFree: 255 MB"
                ]
            } else if args == "/proc/cpuinfo" {
                return [
                    "processor: 0",
                    "hart: 0",
                    "isa: rv64imac",
                    "mmu: sv39"
                ]
            } else if args == "/etc/version" {
                return [
                    "Leenux OS v0.3",
                    "Build: 2026-02-07"
                ]
            }
            return ["File not found: \(args)"]
            
        case "pwd":
            return ["/"]
            
        case "cd":
            return [] // Acknowledged
            
        case "free":
            return [
                "Total: 252 MB",
                "Used: 0 MB",
                "Free: 252 MB"
            ]
            
        case "malloc":
            return ["Allocated: 0x10400010"]
            
        case "memtest":
            return [
                "Test 1: Alloc 128B -> OK",
                "Test 2: Alloc 256B -> OK",
                "Test 3: Free -> OK",
                "Test 4: Realloc -> OK",
                "Test 5: Free all -> OK",
                "Memtest passed!"
            ]
            
        case "format":
            return [
                "Formatting disk with SFS...",
                "Done!"
            ]
            
        case "df":
            return [
                "Disk usage:",
                "Total: 32 MB",
                "Used: 64 KB",
                "Free: 31.9 MB",
                "Inodes: 1/256"
            ]
            
        case "touch":
            if !args.isEmpty {
                return ["Created: \(args)"]
            }
            return ["Usage: touch <filename>"]
            
        case "mkdir":
            if !args.isEmpty {
                return ["Created directory: \(args)"]
            }
            return ["Usage: mkdir <dirname>"]
            
        default:
            return ["Unknown command: \(cmd)"]
        }
    }
}
