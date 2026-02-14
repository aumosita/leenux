// Cross-Platform Double-Buffered Framebuffer
// Compatible with: macOS, Linux, BSD, Windows (via Swift)

/// Store Buffer - Platform Independent
class StoreBuffer {
    struct Entry {
        let address: UInt64
        let value: UInt64
        let size: Int
    }
    
    private var buffer: [Entry] = []
    private let capacity: Int
    private let lock = PlatformLock()  // Cross-platform!
    
    // Statistics
    var totalWrites: Int = 0
    var batchedWrites: Int = 0
    var flushCount: Int = 0
    
    init(capacity: Int = 32) {
        self.capacity = capacity
    }
    
    func add(address: UInt64, value: UInt64, size: Int) {
        lock.withLock {
            totalWrites += 1
            
            if buffer.count >= capacity {
                flushInternal()
            }
            
            buffer.append(Entry(address: address, value: value, size: size))
            batchedWrites += 1
        }
    }
    
    func lookup(address: UInt64, size: Int) -> UInt64? {
        return lock.withLock {
            for entry in buffer.reversed() {
                if entry.address == address && entry.size == size {
                    return entry.value
                }
            }
            return nil
        }
    }
    
    func flush<T: MMIODevice>(to device: T) {
        lock.withLock {
            for entry in buffer {
                let offset = entry.address - device.baseAddress
                
                switch entry.size {
                case 1:
                    _ = device.write8(offset: offset, value: UInt8(entry.value & 0xFF))
                case 4:
                    _ = device.write32(offset: offset, value: UInt32(entry.value & 0xFFFFFFFF))
                case 8:
                    _ = device.write64(offset: offset, value: entry.value)
                default:
                    break
                }
            }
            
            buffer.removeAll(keepingCapacity: true)
            flushCount += 1
        }
    }
    
    private func flushInternal() {
        buffer.removeAll(keepingCapacity: true)
        flushCount += 1
    }
    
    func stats() -> (total: Int, batched: Int, flushes: Int, avgBatchSize: Double) {
        return lock.withLock {
            let avgBatch = flushCount > 0 ? Double(batchedWrites) / Double(flushCount) : 0.0
            return (totalWrites, batchedWrites, flushCount, avgBatch)
        }
    }
    
    func clear() {
        lock.withLock {
            buffer.removeAll()
        }
    }
}

/// Cross-Platform Double-Buffered Framebuffer
/// Uses standard Swift arrays and PlatformLock for maximum compatibility
class DoubleBufferedFramebuffer_CrossPlatform: MMIODevice {
    let name = " Framebuffer
