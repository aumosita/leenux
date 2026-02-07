import Foundation

/// 멀티코어 RISC-V 시스템
///
/// 여러 개의 RISC-V 코어가 공유 메모리를 통해 통신하는 시스템
///
/// 아키텍처:
/// ```
/// ┌─────────────────────────────────────┐
/// │     Multi-Core RISC-V System        │
/// ├─────────────────────────────────────┤
/// │  Core 0    Core 1    ...   Core N   │
/// │    │         │                │     │
/// │    └─────────┴────────────────┘     │
/// │              │                      │
/// │        ┌─────▼──────┐               │
/// │        │ Memory Bus │               │
/// │        └─────┬──────┘               │
/// │              │                      │
/// │        ┌─────▼──────┐               │
/// │        │   Shared   │               │
/// │        │   Memory   │               │
/// │        └────────────┘               │
/// └─────────────────────────────────────┘
/// ```
#if os(macOS)
@available(macOS 10.15.4, *)
#endif
class MultiCoreSystem {
    // MARK: - Properties
    
    /// 코어 배열
    var cores: [CoreSimple]
    
    /// 메모리 버스
    let memoryBus: MemoryBus
    
    /// 시스템 설정
    let numCores: Int
    let memorySize: Int
    
    /// Kernel & Scheduler
    var scheduler: Scheduler?
    var kernel: Kernel?
    
    /// 실행 상태
    var totalCycles: Int
    var debug: Bool
    
    /// MMIO 디바이스들
    var uart: UARTDevice?
    var timer: TimerDevice?
    var framebuffer: FramebufferDevice?
    var keyboard: KeyboardDevice?
    var disk: DiskDevice?
    
    // MARK: - Initialization
    
    /// 멀티코어 시스템 초기화
    /// - Parameters:
    ///   - numCores: 코어 개수 (기본값: 4)
    ///   - memorySize: 공유 메모리 크기 (기본값: 8MB)
    ///   - startPC: 시작 PC 주소 (기본값: 0x1000)
    ///   - memoryLatency: 메모리 접근 지연 사이클 (기본값: 1)
    ///   - enableArbitration: 메모리 버스 중재 활성화 (기본값: true for multi-core)
    ///   - enableCache: L1 캐시 활성화 (기본값: true)
    init(numCores: Int = 4, memorySize: Int = 8 * 1024 * 1024, startPC: UInt64 = 0x1000, 
         memoryLatency: Int = 1, enableArbitration: Bool? = nil, enableCache: Bool = true) {
        self.numCores = numCores
        self.memorySize = memorySize
        let sharedMemory = SharedMemory(size: memorySize)
        
        // 멀티코어인 경우 기본적으로 중재 활성화
        let shouldArbitrate = enableArbitration ?? (numCores > 1)
        self.memoryBus = MemoryBus(memory: sharedMemory, numCores: numCores, 
                                    memoryLatency: memoryLatency, 
                                    enableArbitration: shouldArbitrate)
        self.cores = []
        self.totalCycles = 0
        self.debug = false
        
        // 코어 초기화
        for coreId in 0..<numCores {
            let core = CoreSimple(id: coreId, memoryBus: memoryBus, startPC: startPC, enableCache: enableCache)
            cores.append(core)
        }

        // Kernel & Scheduler
        let kernel = Kernel(system: self)
        self.scheduler = Scheduler(cores: self.cores, kernel: kernel)
        self.kernel = kernel

        // MMIO 디바이스 초기화 및 등록
        self.uart = UARTDevice()
        self.timer = TimerDevice()
        self.framebuffer = FramebufferDevice(width: 1024, height: 768)
        self.keyboard = KeyboardDevice()
        self.disk = DiskDevice(memory: sharedMemory, imagePath: "disk.img")
        
        // SharedMemory에 디바이스 등록
        if let uart = self.uart {
            memoryBus.memory.registerDevice(uart)
        }
        if let timer = self.timer {
            memoryBus.memory.registerDevice(timer)
        }
        if let framebuffer = self.framebuffer {
            memoryBus.memory.registerDevice(framebuffer)
        }
        if let keyboard = self.keyboard {
            memoryBus.memory.registerDevice(keyboard)
        }
        if let disk = self.disk {
            memoryBus.memory.registerDevice(disk)
            print("🔌 Registered MMIO device: Disk at 0x15000000")
        }
        
        // Interrupt Routing (Wire Timer -> Core 0 MIP.MTIP (Bit 7))
        if let timer = self.timer, !cores.isEmpty {
            timer.onInterrupt = { [weak self] active in
                self?.cores[0].runInterrupt(bit: 7, active: active)
            }
        }

        print("🖥️  Multi-Core RISC-V System initialized")
        print("   Cores: \(numCores)")
        print("   Memory: \(memorySize / 1024 / 1024) MB")
        print("   Memory latency: \(memoryLatency) cycle(s)")
        print("   Bus arbitration: \(shouldArbitrate ? "enabled" : "disabled")")
        print("   L1 Cache: \(enableCache ? "enabled" : "disabled")")
        print("   Start PC: \(String(format: "0x%X", startPC))")
        print("")
    }
    
    // MARK: - Program Loading
    
    /// 프로그램을 메모리에 로드
    /// - Parameters:
    ///   - address: 로드할 메모리 주소
    ///   - data: 프로그램 바이너리 데이터
    /// - Returns: 로드 성공 여부
    func loadProgram(at address: UInt64, data: [UInt8]) -> Bool {
        guard memoryBus.loadProgram(at: address, data: data) else {
            print("❌ Failed to load program at \(String(format: "0x%X", address))")
            return false
        }
        
        print("📂 Program loaded at \(String(format: "0x%X", address)) (\(data.count) bytes)")
        
        // Debug: Verify memory contents after loading
        if debug {
            let loaded = memoryBus.dumpMemory(start: address, length: min(data.count, 64))
            print("   Memory verification at 0x\(String(format: "%X", address)):")
            for (i, byte) in loaded.prefix(64).enumerated() {
                if i % 16 == 0 { print("   ", terminator: "") }
                print(String(format: "%02X ", byte), terminator: "")
                if i % 16 == 15 { print("") }
            }
            if loaded.count % 16 != 0 { print("") }
        }
        
        return true
    }
    
    /// 파일에서 프로그램 로드
    /// - Parameters:
    ///   - path: 바이너리 파일 경로
    ///   - address: 로드할 메모리 주소
    /// - Returns: 로드 성공 여부
    func loadProgramFromFile(path: String, at address: UInt64 = 0x1000) -> Bool {
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            return loadProgram(at: address, data: Array(data))
        } catch {
            print("❌ Failed to load file: \(error)")
            return false
        }
    }
    
    // MARK: - Execution
    
    /// 단일 코어 모드로 실행
    /// - Parameters:
    ///   - coreId: 실행할 코어 ID
    ///   - maxCycles: 최대 사이클 수
    func runSingleCore(coreId: Int = 0, maxCycles: Int = 10000) {
        guard coreId < numCores else {
            print("❌ Invalid core ID: \(coreId)")
            return
        }
        
        print("")
        print("🚀 Starting single-core execution (Core \(coreId))...")
        print("   Max cycles: \(maxCycles)")
        print("")
        
        let core = cores[coreId]
        core.debug = debug
        
        totalCycles = 0
        while totalCycles < maxCycles && !core.halted {
            // Batch memory access for performance
            memoryBus.batch {
                core.tick()
                memoryBus.tick()
            }
            totalCycles += 1
        }
        
        printSingleCoreSummary(core: core)
    }
    
    /// 멀티코어 모드로 실행 (순차 실행 - 호환성)
    /// - Parameter maxCycles: 최대 사이클 수
    func runMultiCore(maxCycles: Int = 10000) {
        print("")
        print("🚀 Starting multi-core execution...")
        print("   Cores: \(numCores)")
        print("   Max cycles: \(maxCycles)")
        print("")
        
        // 모든 코어 디버그 모드 설정
        for core in cores {
            core.debug = debug
        }
        
        totalCycles = 0
        var allHalted = false
        
        while totalCycles < maxCycles && !allHalted {
            // Batch memory access for performance
            memoryBus.batch {
                // 각 코어 한 사이클 실행
                for core in cores {
                    if !core.halted {
                        core.tick()
                    }
                }
                
                // 메모리 버스 (중재) Tick
                memoryBus.tick()
            }
            
            totalCycles += 1
            
            // 디버그 출력
            if debug && totalCycles % 100 == 0 {
                print("System Cycle \(totalCycles)")
            }
            
            // 모든 코어가 정지했는지 확인
            allHalted = cores.allSatisfy { $0.halted }
        }
        
        printMultiCoreSummary()
    }
    
    /// 멀티코어 병렬 실행 (호스트 CPU 완전 활용) ⭐
    /// - Parameters:
    ///   - maxCycles: 최대 사이클 수
    ///   - quantum: 각 코어가 한 번에 실행할 명령어 수
    func runMultiCoreParallel(maxCycles: Int = 10000, quantum: Int = 4) {
        print("")
        print("🚀 Starting PARALLEL multi-core execution...")
        print("   Cores: \(numCores)")
        print("   Max cycles: \(maxCycles)")
        print("   Quantum: \(quantum)")
        print("   Mode: TRUE PARALLELISM (호스트 CPU 활용)")
        print("")
        
        // 모든 코어 디버그 모드 설정
        for core in cores {
            core.debug = debug
        }
        
        // Scheduler로 병렬 실행 시작
        scheduler?.startMultiThreaded(quantum: quantum)
        
        // 실행 시간 측정 시작
        let startTime = Date()
        
        // 모든 코어가 종료될 때까지 대기
        var elapsed: TimeInterval = 0
        while !cores.allSatisfy({ $0.halted }) && elapsed < Double(maxCycles) / 1000.0 {
            Thread.sleep(forTimeInterval: 0.01)  // 10ms마다 체크
            elapsed = Date().timeIntervalSince(startTime)
            
            // 타임아웃 체크 (maxCycles 기반)
            let estimatedCycles = cores.map { $0.cyclesExecuted }.max() ?? 0
            if estimatedCycles >= maxCycles {
                break
            }
        }
        
        // Scheduler 종료
        scheduler?.shutdown()
        
        // 실행 시간
        let executionTime = Date().timeIntervalSince(startTime)
        
        // 총 사이클 계산 (가장 많이 실행한 코어 기준)
        totalCycles = cores.map { $0.cyclesExecuted }.max() ?? 0
        
        printMultiCoreParallelSummary(executionTime: executionTime)
    }
    
    // MARK: - Summary
    
    /// 단일 코어 실행 요약 출력
    private func printSingleCoreSummary(core: CoreSimple) {
        print("")
        print("=" + String(repeating: "=", count: 60))
        print("📊 Single-Core Execution Summary")
        print("=" + String(repeating: "=", count: 60))
        
        if core.halted {
            print("✅ Core halted (EBREAK)")
        } else {
            print("⚠️  Max cycles (\(totalCycles)) reached")
        }
        
        print("")
        core.printStatus()
        
        print("")
        print("Register Contents:")
        printRegisters(core: core)
        
        print("")
        memoryBus.printStats()
        print("")
        print("Branch Prediction:")
        if core.branchPredictor.totalPredictions > 0 {
            core.branchPredictor.printStats()
        } else {
            print("  No branch predictions")
        }
    }
    
    /// 멀티코어 실행 요약 출력
    private func printMultiCoreSummary() {
        print("")
        print("=" + String(repeating: "=", count: 60))
        print("📊 Multi-Core Execution Summary")
        print("=" + String(repeating: "=", count: 60))
        print("Total system cycles: \(totalCycles)")
        print("Number of cores: \(numCores)")
        print("")
        
        var totalInstructions = 0
        var totalStalls = 0
        
        for (i, core) in cores.enumerated() {
            print("─" + String(repeating: "─", count: 60))
            print("Core \(i):")
            print("  Instructions: \(core.instructionsExecuted)")
            print("  Cycles: \(core.cyclesExecuted)")
            print("  CPI: \(String(format: "%.2f", core.cyclesExecuted > 0 ? Double(core.cyclesExecuted) / Double(max(core.instructionsExecuted, 1)) : 0))")
            print("  Stalls: \(core.stallsDetected)")
            print("  Branches: \(core.branchesTaken) taken, \(core.branchesNotTaken) not taken")
            print("  Branch mispredictions: \(core.branchMispredictions)")
            if core.branchPredictor.totalPredictions > 0 {
                print("  Branch prediction accuracy: \(String(format: "%.2f", core.branchPredictor.accuracy))%")
            }
            print("  Halted: \(core.halted)")
            print("  Final PC: \(String(format: "0x%X", core.pc))")
            
            // 주요 레지스터 출력
            if core.registers[10] != 0 || core.registers[11] != 0 {
                print("  a0 (x10): \(core.registers[10])")
                print("  a1 (x11): \(core.registers[11])")
            }
            
            totalInstructions += core.instructionsExecuted
            totalStalls += core.stallsDetected
        }
        
        print("")
        print("─" + String(repeating: "─", count: 60))
        print("System Totals:")
        print("  Total instructions: \(totalInstructions)")
        print("  Total stalls: \(totalStalls)")
        print("  Average IPC: \(String(format: "%.2f", totalCycles > 0 ? Double(totalInstructions) / Double(totalCycles) : 0))")
        print("")
        
        memoryBus.printStats()
        print("")
        
        // Branch prediction statistics
        var totalBranchPredictions = 0
        var totalCorrectPredictions = 0
        for core in cores {
            totalBranchPredictions += core.branchPredictor.totalPredictions
            totalCorrectPredictions += core.branchPredictor.correctPredictions
        }
        if totalBranchPredictions > 0 {
            let overallAccuracy = Double(totalCorrectPredictions) / Double(totalBranchPredictions) * 100.0
            print("Branch Prediction (Overall):")
            print("  Total predictions: \(totalBranchPredictions)")
            print("  Correct: \(totalCorrectPredictions)")
            print("  Accuracy: \(String(format: "%.2f", overallAccuracy))%")
        }
    }
    
    /// 병렬 멀티코어 실행 요약 출력
    private func printMultiCoreParallelSummary(executionTime: TimeInterval) {
        print("")
        print("=" + String(repeating: "=", count: 60))
        print("📊 PARALLEL Multi-Core Execution Summary")
        print("=" + String(repeating: "=", count: 60))
        print("Number of cores: \(numCores)")
        print("Execution time: \(String(format: "%.3f", executionTime))s")
        print("")
        
        var totalInstructions = 0
        var totalStalls = 0
        var maxCycles = 0
        
        for (i, core) in cores.enumerated() {
            print("─" + String(repeating: "─", count: 60))
            print("Core \(i):")
            print("  Instructions: \(core.instructionsExecuted)")
            print("  Cycles: \(core.cyclesExecuted)")
            print("  CPI: \(String(format: "%.2f", core.cyclesExecuted > 0 ? Double(core.cyclesExecuted) / Double(max(core.instructionsExecuted, 1)) : 0))")
            print("  Stalls: \(core.stallsDetected)")
            print("  Branches: \(core.branchesTaken) taken, \(core.branchesNotTaken) not taken")
            print("  Branch mispredictions: \(core.branchMispredictions)")
            if core.branchPredictor.totalPredictions > 0 {
                print("  Branch prediction accuracy: \(String(format: "%.2f", core.branchPredictor.accuracy))%")
            }
            print("  Halted: \(core.halted)")
            print("  Final PC: \(String(format: "0x%X", core.pc))")
            
            // 주요 레지스터 출력
            if core.registers[10] != 0 || core.registers[11] != 0 {
                print("  a0 (x10): \(core.registers[10])")
                print("  a1 (x11): \(core.registers[11])")
            }
            
            totalInstructions += core.instructionsExecuted
            totalStalls += core.stallsDetected
            maxCycles = max(maxCycles, core.cyclesExecuted)
        }
        
        print("")
        print("─" + String(repeating: "─", count: 60))
        print("System Totals:")
        print("  Total instructions: \(totalInstructions)")
        print("  Total stalls: \(totalStalls)")
        print("  Max cycles (longest core): \(maxCycles)")
        print("  Aggregate IPC: \(String(format: "%.2f", maxCycles > 0 ? Double(totalInstructions) / Double(maxCycles) : 0))")
        print("  Instructions/second: \(String(format: "%.0f", executionTime > 0 ? Double(totalInstructions) / executionTime : 0))")
        print("")
        print("🚀 Parallelism:")
        print("  Host CPU cores used: \(numCores)")
        print("  Theoretical speedup: \(numCores)x")
        let sequentialTime = Double(maxCycles) * Double(numCores)
        let actualSpeedup = sequentialTime / Double(maxCycles)
        print("  Actual speedup: \(String(format: "%.2f", actualSpeedup))x")
        print("  Parallel efficiency: \(String(format: "%.1f", actualSpeedup / Double(numCores) * 100))%")
        print("")
        
        memoryBus.printStats()
        print("")
        
        // Branch prediction statistics
        var totalBranchPredictions = 0
        var totalCorrectPredictions = 0
        for core in cores {
            totalBranchPredictions += core.branchPredictor.totalPredictions
            totalCorrectPredictions += core.branchPredictor.correctPredictions
        }
        if totalBranchPredictions > 0 {
            let overallAccuracy = Double(totalCorrectPredictions) / Double(totalBranchPredictions) * 100.0
            print("Branch Prediction (Overall):")
            print("  Total predictions: \(totalBranchPredictions)")
            print("  Correct: \(totalCorrectPredictions)")
            print("  Accuracy: \(String(format: "%.2f", overallAccuracy))%")
        }
    }
    
    /// 레지스터 내용 출력
    private func printRegisters(core: CoreSimple) {
        let regNames = [
            "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
            "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
            "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
            "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
        ]
        
        for i in 0..<32 {
            if core.registers[i] != 0 {
                print("  x\(i) (\(regNames[i].padding(toLength: 4, withPad: " ", startingAt: 0))) = \(core.registers[i])")
            }
        }
    }
    
    // MARK: - Utilities
    
    /// 특정 코어의 레지스터 값 읽기
    /// - Parameters:
    ///   - coreId: 코어 ID
    ///   - regNum: 레지스터 번호
    /// - Returns: 레지스터 값
    func readRegister(coreId: Int, regNum: Int) -> UInt64? {
        guard coreId < numCores && regNum < 32 else { return nil }
        return cores[coreId].registers[regNum]
    }
    
    /// 메모리 덤프
    /// - Parameters:
    ///   - start: 시작 주소
    ///   - length: 길이
    func dumpMemory(start: UInt64, length: Int) {
        let data = memoryBus.dumpMemory(start: start, length: length)
        print("Memory dump at \(String(format: "0x%X", start)):")
        
        for (i, byte) in data.enumerated() {
            if i % 16 == 0 {
                print(String(format: "\n0x%04X: ", start + UInt64(i)), terminator: "")
            }
            print(String(format: "%02X ", byte), terminator: "")
        }
        print("")
    }
    
    /// 통계 리셋
    func resetStats() {
        totalCycles = 0
        memoryBus.resetStats()
        
        for core in cores {
            core.cyclesExecuted = 0
            core.instructionsExecuted = 0
            core.stallsDetected = 0
            core.branchesTaken = 0
            core.branchesNotTaken = 0
            core.branchMispredictions = 0
            core.branchPredictor.resetStats()
        }
    }
}
