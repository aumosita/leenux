import Foundation

// MARK: - Cache Line

/// 캐시 라인 (64 bytes)
struct CacheLine {
    var valid: Bool = false
    var tag: UInt64 = 0
    var data: [UInt8] = Array(repeating: 0, count: 64)
    var dirty: Bool = false  // Write-back용
    
    init() {
        self.valid = false
        self.tag = 0
        self.data = Array(repeating: 0, count: 64)
        self.dirty = false
    }
}

// MARK: - L1 Cache

/// L1 Data Cache (Direct-Mapped)
///
/// 구조:
/// - 64 sets
/// - 1-way (direct-mapped)
/// - 64 bytes per line
/// - Total: 4 KB
class L1Cache {
    // MARK: - Configuration
    
    let numSets: Int = 64
    let blockSize: Int = 64  // bytes per cache line
    let hitLatency: Int = 1   // cycles
    let missLatency: Int = 10 // cycles (메모리 접근)
    
    // MARK: - State
    
    private var cache: [CacheLine]
    
    /// 통계
    var totalAccesses: Int = 0
    var hits: Int = 0
    var misses: Int = 0
    var evictions: Int = 0
    
    // MARK: - Initialization
    
    init() {
        self.cache = Array(repeating: CacheLine(), count: numSets)
    }
    
    // MARK: - Address Parsing
    
    /// 주소를 tag, set index, block offset으로 분해
    private func parseAddress(_ address: UInt64) -> (tag: UInt64, setIndex: Int, blockOffset: Int) {
        let blockOffset = Int(address & 0x3F)  // 하위 6비트 (64 bytes)
        let setIndex = Int((address >> 6) & 0x3F)  // 다음 6비트 (64 sets)
        let tag = address >> 12  // 상위 비트
        return (tag, setIndex, blockOffset)
    }
    
    // MARK: - Cache Operations
    
    /// MMIO 주소 판단 (캐시 불가)
    private func isUncacheable(_ address: UInt64) -> Bool {
        // MMIO 영역 (0x1000_0000 ~ 0x1FFF_FFFF)
        return address >= 0x1000_0000 && address < 0x2000_0000
    }
    
    /// 캐시에서 읽기
    /// - Parameter address: 메모리 주소
    /// - Returns: (hit 여부, 데이터, latency)
    func read(address: UInt64, size: Int) -> (hit: Bool, data: UInt64?, latency: Int) {
        totalAccesses += 1
        
        // MMIO 주소는 캐시 안 함 (miss 반환)
        if isUncacheable(address) {
            misses += 1
            return (false, nil, 1)  // 직접 메모리 접근
        }
        
        let (tag, setIndex, blockOffset) = parseAddress(address)
        let line = cache[setIndex]
        
        // Cache hit
        if line.valid && line.tag == tag {
            hits += 1
            let data = extractData(from: line.data, offset: blockOffset, size: size)
            return (true, data, hitLatency)
        }
        
        // Cache miss
        misses += 1
        return (false, nil, missLatency)
    }
    
    /// 캐시에 쓰기 (Write-through)
    /// - Parameters:
    ///   - address: 메모리 주소
    ///   - data: 쓸 데이터
    ///   - size: 데이터 크기
    /// - Returns: (hit 여부, latency)
    func write(address: UInt64, data: UInt64, size: Int) -> (hit: Bool, latency: Int) {
        totalAccesses += 1
        
        // MMIO 주소는 캐시 안 함 (miss 반환, 직접 메모리 접근)
        if isUncacheable(address) {
            misses += 1
            return (false, 1)  // 직접 메몠리 접근
        }
        
        let (tag, setIndex, blockOffset) = parseAddress(address)
        var line = cache[setIndex]
        
        // Cache hit - update cache and memory (write-through)
        if line.valid && line.tag == tag {
            hits += 1
            insertData(into: &line.data, offset: blockOffset, data: data, size: size)
            cache[setIndex] = line
            return (true, hitLatency)
        }
        
        // Cache miss - write to memory only (no-write-allocate)
        misses += 1
        return (false, missLatency)
    }
    
    /// 캐시 라인 로드 (miss 후 메모리에서 가져올 때)
    /// - Parameters:
    ///   - address: 메모리 주소
    ///   - data: 메모리에서 읽은 블록 데이터
    func loadLine(address: UInt64, data: [UInt8]) {
        let (tag, setIndex, _) = parseAddress(address)
        var line = cache[setIndex]
        
        // Eviction 감지
        if line.valid {
            evictions += 1
        }
        
        // 새 라인 로드
        line.valid = true
        line.tag = tag
        line.data = data
        line.dirty = false
        
        cache[setIndex] = line
    }
    
    /// 캐시 무효화 (특정 주소)
    func invalidate(address: UInt64) {
        let (tag, setIndex, _) = parseAddress(address)
        var line = cache[setIndex]
        
        if line.valid && line.tag == tag {
            line.valid = false
            cache[setIndex] = line
        }
    }
    
    /// 전체 캐시 플러시
    func flush() {
        for i in 0..<numSets {
            cache[i].valid = false
        }
    }
    
    // MARK: - Helper Functions
    
    /// 캐시 라인에서 데이터 추출
    private func extractData(from lineData: [UInt8], offset: Int, size: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0..<size {
            if offset + i < lineData.count {
                result |= UInt64(lineData[offset + i]) << (i * 8)
            }
        }
        return result
    }
    
    /// 캐시 라인에 데이터 삽입
    private func insertData(into lineData: inout [UInt8], offset: Int, data: UInt64, size: Int) {
        for i in 0..<size {
            if offset + i < lineData.count {
                lineData[offset + i] = UInt8((data >> (i * 8)) & 0xFF)
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Hit rate 계산
    var hitRate: Double {
        guard totalAccesses > 0 else { return 0.0 }
        return Double(hits) / Double(totalAccesses) * 100.0
    }
    
    /// Miss rate 계산
    var missRate: Double {
        guard totalAccesses > 0 else { return 0.0 }
        return Double(misses) / Double(totalAccesses) * 100.0
    }
    
    /// 평균 접근 시간 (AMAT: Average Memory Access Time)
    var averageAccessTime: Double {
        let hitTime = Double(hitLatency)
        let missTime = Double(missLatency)
        let hitRatio = hitRate / 100.0
        return hitTime + (1.0 - hitRatio) * missTime
    }
    
    /// 통계 리셋
    func resetStats() {
        totalAccesses = 0
        hits = 0
        misses = 0
        evictions = 0
    }
    
    /// 통계 출력
    func printStats() {
        print("L1 Cache Statistics:")
        print("  Total accesses: \(totalAccesses)")
        print("  Hits: \(hits)")
        print("  Misses: \(misses)")
        print("  Evictions: \(evictions)")
        print("  Hit rate: \(String(format: "%.2f", hitRate))%")
        print("  Miss rate: \(String(format: "%.2f", missRate))%")
        print("  Average access time: \(String(format: "%.2f", averageAccessTime)) cycles")
    }
}
