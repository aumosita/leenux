import Foundation



// RISC-V 64I Multi-Core Emulator Entry Point
// Usage: risc-emulator <binary_file> [options]

/// 헥사 파일에서 바이트 배열 로드
func loadHexFile(path: String) throws -> [UInt8] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    let hexStrings = content.split(separator: " ").map { String($0) }
    return hexStrings.compactMap { UInt8($0, radix: 16) }
}

/// 바이너리 파일에서 바이트 배열 로드
func loadBinaryFile(path: String) throws -> [UInt8] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return Array(data)
}

/// 사용법 출력
func printUsage(_ programName: String) {
    print("""
    RISC-V 64I Multi-Core Emulator
    
    Usage: \(programName) <binary_file> [options]
    
    Options:
      --cores N            Number of cores (1-8, default: 1)
      --max-cycles N       Maximum cycles to execute (default: 10000)
      --memory N           Memory size in MB (default: 8)
      --parallel           Enable TRUE parallel execution (use host CPUs)
      --quantum N          Quantum size for parallel mode (default: 4)
      --debug              Enable debug output
      --help               Show this help message
    
    Examples:
      # Single core (pipeline)
      \(programName) Examples/01_arithmetic.bin
      
      # Multi-core with 4 cores
      \(programName) Examples/10_multicore_test.bin --cores 4
      
      # Parallel execution (TRUE parallelism)
      \(programName) program.bin --cores 4 --parallel
      
      # Custom memory size (64 MB)
      \(programName) program.bin --memory 64
      
      # Large memory with multiple cores
      \(programName) program.bin --cores 8 --memory 128
      
      # Debug mode
      \(programName) Examples/02_memory.bin --debug
    
    Example Programs:
      01_arithmetic.bin        - Basic arithmetic operations
      02_memory.bin            - Memory load/store operations
      03_branches.bin          - Branch instructions
      04_function_call.bin     - Function calls with stack
      05_comprehensive.bin     - Comprehensive test
      07_m_extension_division.bin - M extension (division)
      09_m_extension_simple.bin   - M extension (simple test)
    
    Features:
      - RV64I base instruction set
      - M extension (multiplication/division)
      - 5-stage pipeline per core
      - Shared memory architecture
      - Hazard detection and forwarding
    """)
}

/// 메인 함수
/// 메인 함수
#if os(macOS)
@available(macOS 10.15.4, *)
#endif
func main() {
    let arguments = CommandLine.arguments
    let programName = (arguments[0] as NSString).lastPathComponent
    
    // Check for test flags first (they don't need a binary file)
    let isTestMode = arguments.contains("--test-sys-exit") || 
                     arguments.contains("--test-sys-spawn") || 
                     arguments.contains("--test-sys-yield")
    
    // Check for help flag
    if !isTestMode && (arguments.count < 2 || arguments.contains("--help")) {
        printUsage(programName)
        exit(arguments.contains("--help") ? 0 : 1)
    }
    
    let filePath = isTestMode ? "" : arguments[1]
    let debug = arguments.contains("--debug")
    let useParallel = arguments.contains("--parallel")
    
    var maxCycles = 10000
    var numCores = 1
    var quantum = 4
    
    // Parse max-cycles option
    if let maxCyclesIndex = arguments.firstIndex(of: "--max-cycles"),
       maxCyclesIndex + 1 < arguments.count,
       let cycles = Int(arguments[maxCyclesIndex + 1]) {
        maxCycles = cycles
    }
    
    // Parse cores option
    if let coresIndex = arguments.firstIndex(of: "--cores"),
       coresIndex + 1 < arguments.count,
       let cores = Int(arguments[coresIndex + 1]) {
        numCores = min(max(cores, 1), 8)  // 1-8 cores
    }
    
    // Parse quantum option
    if let quantumIndex = arguments.firstIndex(of: "--quantum"),
       quantumIndex + 1 < arguments.count,
       let q = Int(arguments[quantumIndex + 1]) {
        quantum = max(q, 1)
    }
    
    // Parse memory size (in MB)
    var memorySize = 8 * 1024 * 1024  // Default: 8MB
    if let memIndex = arguments.firstIndex(of: "--memory"),
       memIndex + 1 < arguments.count,
       let memorySizeMB = Int(arguments[memIndex + 1]) {
        memorySize = memorySizeMB * 1024 * 1024  // Convert MB to bytes
        print("💾 Memory size: \(memorySizeMB) MB")
    }
    
    // Load program (skip for test mode)
    var program: [UInt8] = []
    if !isTestMode {
        do {
            if filePath.hasSuffix(".hex") {
                program = try loadHexFile(path: filePath)
                print("📂 Loaded hex file: \(filePath) (\(program.count) bytes)")
            } else {
                program = try loadBinaryFile(path: filePath)
                print("📂 Loaded binary file: \(filePath) (\(program.count) bytes)")
            }
        } catch {
            print("❌ Error loading file \(filePath): \(error)")
            exit(1)
        }
    }
    
    // Initialize multi-core system
    let system = MultiCoreSystem(numCores: numCores, memorySize: memorySize)
    system.debug = debug
    
    // Load program only if not in test mode
    if !isTestMode {
        guard system.loadProgram(at: 0x1000, data: program) else {
            exit(1)
        }
    }

    // Start background stdin monitoring (to support pipes/integration)
    FileHandle.standardInput.readabilityHandler = { handle in
        let data = handle.availableData
        if !data.isEmpty {
            if let str = String(data: data, encoding: .utf8) {
                if debug { print("📝 Stdin received: \(str.count) bytes: \(str.trimmingCharacters(in: .newlines))") }
                for char in str {
                    if let keyboard = system.keyboard {
                        keyboard.pushChar(char)
                    } else if let uart = system.uart {
                        uart.pushInput(char.asciiValue ?? 0)
                    }
                }
            }
        }
    }

        // Test hooks (disabled for CoreSimple)
        if arguments.contains("--test-sys-exit") ||
           arguments.contains("--test-sys-spawn") ||
           arguments.contains("--test-sys-yield") {
            print("WARNING: Syscall tests disabled for CoreSimple")
            exit(0)
        }

    if numCores == 1 {
        // Single core mode
        system.runSingleCore(coreId: 0, maxCycles: maxCycles)
    } else if useParallel {
        // Parallel multi-core mode (TRUE parallelism)
        system.runMultiCoreParallel(maxCycles: maxCycles, quantum: quantum)
    } else {
        // Sequential multi-core mode (compatibility)
        system.runMultiCore(maxCycles: maxCycles)
    }
}

#if os(macOS)
if #available(macOS 10.15.4, *) {
    main()
} else {
    print("Error: macOS 10.15.4 or newer is required.")
    exit(1)
}
#else
main()
#endif
