import Foundation

/// Memory Block Cache
/// 
/// 메모리 블록 단위(256 bytes)로 캐싱하여 fetch 성능 향상
/// TLB (Translation Lookaside Buffer) 시뮬레이션과 유사
class MemoryBlockCache {
    struct Block {
        let baseAddress: UInt64    // 256-byte aligned base address
        var data: [UInt32]          // 64 instructions (256 / 4)
        var lastAccess: Int         // LRU tracking
        
        init(baseAddress: UInt64, data: [UInt32], lastAccess: Int) {
            self.baseAddress = baseAddress
            self.data = data
            self.lastAccess = lastAccess
        }
    }
    
    private var blocks: [UInt64: Block] = [:]
    private let blockSize: UInt64 = 256  // bytes (64 instructions)
    private let capacity: Int
    private var accessCounter: Int = 0
    
    // Statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    
    // Memory bus reference
    private unowned let memoryBus: MemoryBus
    private let coreId: Int
    
    init(memoryBus: MemoryBus, coreId: Int, capacity: Int = 128) {
        self.memoryBus = memoryBus
        self.coreId = coreId
        self.capacity = capacity
        self.blocks.reserveCapacity(capacity)
    }
    
    /// Read 32-bit value from cached memory blocks
    func read32(address: UInt64) -> UInt32? {
        let blockAddr = address & ~(blockSize - 1)  // 256-byte aligned
        
        accessCounter += 1
        
        // Cache hit
        if var block = blocks[blockAddr] {
            hits += 1
            block.lastAccess = accessCounter
            blocks[blockAddr] = block  // Update LRU timestamp
            
            let offset = Int((address - blockAddr) / 4)
            return block.data[offset]
        }
        
        // Cache miss: load block from memory bus
        misses += 1
        
        guard let newBlock = loadBlock(baseAddress: blockAddr) else {
            return nil
        }
        
        blocks[blockAddr] = newBlock
        
        // LRU eviction if capacity exceeded
        if blocks.count > capacity {
            evictLRU()
        }
        
        let offset = Int((address - blockAddr) / 4)
        return newBlock.data[offset]
    }
    
    /// Write-through: invalidate cached block
    func write32(address: UInt64, value: UInt32) {
        let blockAddr = address & ~(blockSize - 1)
        
        // Write through to memory bus
        memoryBus.write32(coreId: coreId, address: address, value: value)
        
        // Invalidate cached block (simple write-through policy)
        blocks.removeValue(forKey: blockAddr)
    }
    
    // MARK: - Private Helpers
    
    /// Load a memory block from the bus
    private func loadBlock(baseAddress: UInt64) -> Block? {
        var data: [UInt32] = []
        data.reserveCapacity(64)  // 256 bytes / 4
        
        for offset in stride(from: 0, to: blockSize, by: 4) {
            guard let value = memoryBus.read32(coreId: coreId, address: baseAddress + offset) else {
                return nil
            }
            data.append(value)
        }
        
        return Block(baseAddress: baseAddress, data: data, lastAccess: accessCounter)
    }
    
    /// Evict least recently used block
    private func evictLRU() {
        guard let lruKey = blocks.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
            return
        }
        blocks.removeValue(forKey: lruKey)
    }
    
    // MARK: - Statistics
    
    /// Cache hit rate (%)
    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) * 100 : 0
    }
    
    /// Current number of cached blocks
    var count: Int { blocks.count }
    
    /// Total memory used by cache
    var memoryUsed: Int { blocks.count * 256 }  // bytes
    
    /// Reset statistics
    func resetStats() {
        hits = 0
        misses = 0
    }
    
    /// Clear all cached blocks
    func clear() {
        blocks.removeAll(keepingCapacity: true)
        resetStats()
    }
}
