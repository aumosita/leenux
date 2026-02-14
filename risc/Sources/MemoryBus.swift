import Foundation

// MARK: - Memory Request

/// 메모리 요청 타입
enum MemoryRequestType {
    case read8, read16, read32, read64
    case write8(UInt8), write16(UInt16), write32(UInt32), write64(UInt64)
}

/// 메모리 요청
struct MemoryRequest {
    let coreId: Int
    let address: UInt64
    let type: MemoryRequestType
    let timestamp: Int  // 요청 시간 (사이클)
}

/// 메모리 응답
struct MemoryResponse {
    let success: Bool
    let data: UInt64?  // 읽기 요청의 경우
    let latency: Int   // 대기 사이클 수
}

// MARK: - Memory Bus with Arbitration

/// 메모리 버스 중재자 (Round-Robin)
///
/// 여러 코어가 동시에 메모리 접근 시 충돌을 해결합니다.
/// Round-robin 방식으로 공정하게 중재합니다.
class MemoryBus {
    // MARK: - Properties
    
    /// 공유 메모리 (디바이스 등록을 위해 공개)
    let memory: SharedMemory
    let numCores: Int
    
    /// 통계
    var totalRequests: Int = 0
    var totalReads: Int = 0
    var totalWrites: Int = 0
    var totalConflicts: Int = 0
    var totalWaitCycles: Int = 0
    
    /// 중재 및 실행 상태
    private var currentCore: Int = 0
    private var busyCycles: Int = 0
    private var currentCycle: Int = 0
    
    // Active Request being processed
    private var processingRequest: MemoryRequest?
    
    /// 대기 큐 (Requests waiting to be serviced)
    private var pendingRequests: [Int: [MemoryRequest]] = [:]
    
    /// 응답 큐 (Completed responses waiting to be consumed by Core)
    private var responseQueue: [Int: [MemoryResponse]] = [:]
    
    /// 설정
    let memoryLatency: Int
    let enableArbitration: Bool
    
    // MARK: - Initialization
    
    init(memory: SharedMemory, numCores: Int = 1, memoryLatency: Int = 1, enableArbitration: Bool = true) {
        self.memory = memory
        self.numCores = numCores
        self.memoryLatency = memoryLatency
        self.enableArbitration = enableArbitration
        
        // 큐 초기화
        for i in 0..<numCores {
            pendingRequests[i] = []
            responseQueue[i] = []
        }
    }
    
    // MARK: - Safe Access Wrappers
    
    func batch(_ block: () -> Void) {
        memory.batch(block)
    }
    
    func loadProgram(at address: UInt64, data: [UInt8]) -> Bool {
        return memory.loadProgram(at: address, data: data)
    }
    
    func dumpMemory(start: UInt64, length: Int) -> [UInt8] {
        return memory.dump(start: start, length: length)
    }
    
    // MARK: - Public Interface (Synchronous - for backward compatibility)
    
    /// 8비트 읽기 (동기)
    func read8(coreId: Int, address: UInt64) -> UInt8? {
        if !enableArbitration {
            // 중재 비활성화 시 즉시 처리
            totalRequests += 1
            totalReads += 1
            return memory.load8(address: address)
        }
        
        // 중재 활성화 시 요청 제출 및 대기
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .read8, timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.data.map { UInt8($0 & 0xFF) }
    }
    
    /// 16비트 읽기 (동기)
    func read16(coreId: Int, address: UInt64) -> UInt16? {
        if !enableArbitration {
            totalRequests += 1
            totalReads += 1
            return memory.load16(address: address)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .read16, timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.data.map { UInt16($0 & 0xFFFF) }
    }
    
    /// 32비트 읽기 (동기)
    func read32(coreId: Int, address: UInt64) -> UInt32? {
        if !enableArbitration {
            totalRequests += 1
            totalReads += 1
            return memory.load32(address: address)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .read32, timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.data.map { UInt32($0 & 0xFFFFFFFF) }
    }
    
    /// 64비트 읽기 (동기)
    func read64(coreId: Int, address: UInt64) -> UInt64? {
        if !enableArbitration {
            totalRequests += 1
            totalReads += 1
            return memory.load64(address: address)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .read64, timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.data
    }
    
    /// 8비트 쓰기 (동기)
    func write8(coreId: Int, address: UInt64, value: UInt8) -> Bool {
        if !enableArbitration {
            totalRequests += 1
            totalWrites += 1
            return memory.store8(address: address, value: value)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .write8(value), timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.success
    }
    
    /// 16비트 쓰기 (동기)
    func write16(coreId: Int, address: UInt64, value: UInt16) -> Bool {
        if !enableArbitration {
            totalRequests += 1
            totalWrites += 1
            return memory.store16(address: address, value: value)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .write16(value), timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.success
    }
    
    /// 32비트 쓰기 (동기)
    func write32(coreId: Int, address: UInt64, value: UInt32) -> Bool {
        if !enableArbitration {
            totalRequests += 1
            totalWrites += 1
            return memory.store32(address: address, value: value)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .write32(value), timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.success
    }
    
    /// 64비트 쓰기 (동기)
    func write64(coreId: Int, address: UInt64, value: UInt64) -> Bool {
        if !enableArbitration {
            totalRequests += 1
            totalWrites += 1
            return memory.store64(address: address, value: value)
        }
        
        let request = MemoryRequest(coreId: coreId, address: address, 
                                     type: .write64(value), timestamp: currentCycle)
        let response = submitAndWait(request: request)
        return response.success
    }
    
    // MARK: - Arbitration Logic
    
    /// 요청 제출 및 응답 대기 (동기 방식으로 시뮬레이션 maintained for compatibility)
    private func submitAndWait(request: MemoryRequest) -> MemoryResponse {
        sendRequest(request)
        
        // Polling until response available
        // NOTE: This advances global time (tick) which affects ALL cores.
        // For Phase 1, this is acceptable legacy behavior.
        // For Phase 2, Cores must wait asynchronously.
        var waitCycles = 0
        while true {
            tick()
            waitCycles += 1
            
            if let response = getResponse(coreId: request.coreId) {
                return response
            }
            
            if waitCycles > 2000 {
                print("Memory Timeout!")
                return MemoryResponse(success: false, data: nil, latency: waitCycles)
            }
        }
    }
    
    // MARK: - Asynchronous Interface
    
    /// 요청 제출 (Non-blocking)
    func sendRequest(_ request: MemoryRequest) {
        pendingRequests[request.coreId]?.append(request)
        totalRequests += 1
    }
    
    /// 응답 확인 (Non-blocking)
    func getResponse(coreId: Int) -> MemoryResponse? {
        if var queue = responseQueue[coreId], !queue.isEmpty {
            let response = queue.removeFirst()
            responseQueue[coreId] = queue
            return response
        }
        return nil
    }
    
    /// 한 사이클 실행 (중재 및 실행 로직)
    func tick() {
        currentCycle += 1
        
        // 1. 현재 처리 중인 요청이 있는 경우
        if let request = processingRequest {
            if busyCycles > 0 {
                busyCycles -= 1
            }
            
            if busyCycles == 0 {
                // 처리 완료
                let response = performMemoryOp(request: request, latency: memoryLatency) // Latency should match configured? Actually latency is recorded in response.
                
                // 응답 큐에 추가
                responseQueue[request.coreId]?.append(response)
                
                // 상태 초기화
                processingRequest = nil
            } else {
                return // 아직 처리 중
            }
        }
        
        // 2. 새로운 요청 중재 (Round-robin)
        if processingRequest == nil {
            guard let selectedCore = selectNextCore() else { return }
            
            if var queue = pendingRequests[selectedCore], !queue.isEmpty {
                let request = queue.removeFirst()
                pendingRequests[selectedCore] = queue
                
                // 처리 시작
                processingRequest = request
                busyCycles = max(1, memoryLatency) - 1 // 1 cycle minimum consumption for this tick
                
                // 통계
                if pendingRequests.values.contains(where: { !$0.isEmpty }) {
                    totalConflicts += 1
                }
                
                 // 만약 latency가 1이면 즉시 완료 처리 가능? 
                 // cycle-accurate 모델에서는 이번 사이클 말에 완료됨.
                 // 다음 tick() 호출 시 완료 체크하려면 busyCycles = 0 이어야 함.
                 // 여기서는 이번 tick에 선택되었으므로, memoryLatency가 1이면 busyCycles=0으로 설정하여
                 // 다음 tick에 완료되지 않고... 
                 // Logic check:
                 // Tick 1: Select Core A. Latency 1. busy = 0.
                 // Tick 2: processingRequest exists. busy == 0. Done. Result available.
                 // Total 1 cycle delay visible to consumer?
                 // Consumer calls sendRequest (Tick 1 start).
                 // Bus calls tick (Tick 1 end). Request selected. busy=0.
                 // Consumer calls getResponse (Tick 2 start). logic above says processingRequest is NOT nil yet.
                 // Wait, if busy == 0, next Tick handle completion.
                 
                 // Let's refine:
                 // If Latency 1:
                 // Tick 1: Select. busy = 0.
                 // Tick 2: if processingRequest & busy==0 -> Done.
                 // So data available after Tick 2. That is 2 cycles latency observed?
                 // Ideally Latency 1 means available NEXT cycle.
                 // So Tick 1 should Complete if latency is low?
                 // Let's stick to "Start" in this cycle, "Finish" when counters expire.
            }
        }
    }
    
    private func performMemoryOp(request: MemoryRequest, latency: Int) -> MemoryResponse {
        // 실제 메모리 접근
        var data: UInt64? = nil
        var success = false
        
        switch request.type {
        case .read8:
            data = memory.load8(address: request.address).map { UInt64($0) }
            success = data != nil
        case .read16:
            data = memory.load16(address: request.address).map { UInt64($0) }
            success = data != nil
        case .read32:
            data = memory.load32(address: request.address).map { UInt64($0) }
            success = data != nil
        case .read64:
            data = memory.load64(address: request.address)
            success = data != nil
        case .write8(let value):
            success = memory.store8(address: request.address, value: value)
        case .write16(let value):
            success = memory.store16(address: request.address, value: value)
        case .write32(let value):
            success = memory.store32(address: request.address, value: value)
        case .write64(let value):
            success = memory.store64(address: request.address, value: value)
        }
        
        switch request.type {
        case .read8, .read16, .read32, .read64: totalReads += 1
        default: totalWrites += 1
        }
        
        let waitTime = currentCycle - request.timestamp
        totalWaitCycles += waitTime
        
        return MemoryResponse(success: success, data: data, latency: waitTime)
    }
    
    /// Round-robin으로 다음 코어 선택
    private func selectNextCore() -> Int? {
        // 현재 코어부터 시작하여 순환
        for offset in 0..<numCores {
            let coreId = (currentCore + offset) % numCores
            if let queue = pendingRequests[coreId], !queue.isEmpty {
                currentCore = (coreId + 1) % numCores  // 다음 코어로 이동
                return coreId
            }
        }
        return nil  // 대기 중인 요청 없음
    }
    

    
    // MARK: - Statistics
    
    /// 통계 리셋
    func resetStats() {
        totalRequests = 0
        totalReads = 0
        totalWrites = 0
        totalConflicts = 0
        totalWaitCycles = 0
        currentCycle = 0
    }
    
    /// 평균 대기 시간
    var averageWaitCycles: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(totalWaitCycles) / Double(totalRequests)
    }
    
    /// 충돌률
    var conflictRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(totalConflicts) / Double(totalRequests) * 100.0
    }
    
    /// 통계 출력
    func printStats() {
        print("Memory Bus Statistics:")
        print("  Total requests: \(totalRequests)")
        print("  Reads: \(totalReads)")
        print("  Writes: \(totalWrites)")
        if enableArbitration {
            print("  Conflicts: \(totalConflicts)")
            print("  Conflict rate: \(String(format: "%.2f", conflictRate))%")
            print("  Total wait cycles: \(totalWaitCycles)")
            print("  Average wait: \(String(format: "%.2f", averageWaitCycles)) cycles")
        }
    }
}
