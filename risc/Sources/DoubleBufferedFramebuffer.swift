import Foundation

/// Store Buffer - Batch memory writes for better performance
class StoreBuffer {
    struct Entry {
        let address: UInt64
        let value: UInt64
        let size: Int  // 1, 4, or 8 bytes
    }
    
    private var buffer: [Entry] = []
    private let capacity: Int
    private let lock = NSLock()
    
    // Statistics
    var totalWrites: Int = 0
    var batchedWrites: Int = 0
    var flushCount: Int = 0
    
    init(capacity: Int = 32) {
        self.capacity = capacity
    }
    
    /// Add write to buffer
    func add(address: UInt64, value: UInt64, size: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        totalWrites += 1
        
        // Check if buffer is full
        if buffer.count >= capacity {
            flushInternal()
        }
        
        buffer.append(Entry(address: address, value: value, size: size))
        batchedWrites += 1
    }
    
    /// Check for store-to-load forwarding
    func lookup(address: UInt64, size: Int) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        
        // Search buffer in reverse (most recent first)
        for entry in buffer.reversed() {
            if entry.address == address && entry.size == size {
                return entry.value
            }
        }
        
        return nil
    }
    
    /// Flush all pending writes
    func flush<T: MMIODevice>(to device: T) {
        lock.lock()
        defer { lock.unlock() }
        
        flushInternal(to: device)
    }
    
    private func flushInternal<T: MMIODevice>(to device: T? = nil) {
        guard !buffer.isEmpty else { return }
        
        flushCount += 1
        
        if let device = device {
            // Actually write to device
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
        }
        
        buffer.removeAll(keepingCapacity: true)
    }
    
    /// Get statistics
    func stats() -> (total: Int, batched: Int, flushes: Int, avgBatchSize: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let avgBatch = flushCount > 0 ? Double(batchedWrites) / Double(flushCount) : 0.0
        return (totalWrites, batchedWrites, flushCount, avgBatch)
    }
    
    /// Clear buffer without flushing
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.removeAll()
    }
}

/// Double-Buffered Framebuffer Device
class DoubleBufferedFramebuffer: MMIODevice {
    let name = "Framebuffer"
    let baseAddress = MemoryMap.FB_BASE
    let size = MemoryMap.FB_SIZE
    
    // MARK: - Properties
    private var width: UInt32 = 1024
    private var height: UInt32 = 768
    private var format: UInt32 = 0
    private var displayEnabled: Bool = true
    
    // Double buffering: front (displayed) and back (being drawn)
    private var frontBuffer: UnsafeMutablePointer<UInt32>
    private var backBuffer: UnsafeMutablePointer<UInt32>
    private let pixelCount: Int
    
    // Locks
    private let writeLock = NSLock()
    private let swapLock = NSLock()
    
    // Store buffer for write coalescing
    private let storeBuffer: StoreBuffer
    
    // Update callback
    var updateCallback: (([UInt32], Int, Int) -> Void)?
    
    // Statistics
    var swapCount: Int = 0
    var writeCount: Int = 0
    
    // MARK: - Initialization
    init(width: Int = 1024, height: Int = 768, storeBufferSize: Int = 32) {
        self.width = UInt32(width)
        self.height = UInt32(height)
        self.pixelCount = width * height
        
        // Allocate two buffers
        self.frontBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: pixelCount)
        self.backBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: pixelCount)
        
        // Initialize both to black
        self.frontBuffer.initialize(repeating: 0xFF000000, count: pixelCount)
        self.backBuffer.initialize(repeating: 0xFF000000, count: pixelCount)
        
        // Create store buffer
        self.storeBuffer = StoreBuffer(capacity: storeBufferSize)
    }
    
    deinit {
        frontBuffer.deinitialize(count: pixelCount)
        frontBuffer.deallocate()
        backBuffer.deinitialize(count: pixelCount)
        backBuffer.deallocate()
    }
    
    // MARK: - Read (from front buffer)
    
    func read8(offset: UInt64) -> UInt8? {
        switch offset {
        case 0x00...0x03:
            let byteIndex = offset - 0x00
            return UInt8((width >> (byteIndex * 8)) & 0xFF)
            
        case 0x04...0x07:
            let byteIndex = offset - 0x04
            return UInt8((height >> (byteIndex * 8)) & 0xFF)
            
        case 0x08...0x0B:
            let byteIndex = offset - 0x08
            return UInt8((format >> (byteIndex * 8)) & 0xFF)
            
        case 0x0C...0x0F:
            let byteIndex = offset - 0x0C
            var control: UInt32 = displayEnabled ? 0x01 : 0x00
            return UInt8((control >> (byteIndex * 8)) & 0xFF)
            
        case 0x1000...:
            let pixelByteOffset = offset - 0x1000
            let pixelIndex = Int(pixelByteOffset / 4)
            let byteInPixel = pixelByteOffset % 4
            
            guard pixelIndex < pixelCount else { return 0 }
            
            // Read from front buffer (displayed)
            let pixel = frontBuffer[pixelIndex]
            return UInt8((pixel >> (byteInPixel * 8)) & 0xFF)
            
        default:
            return 0
        }
    }
    
    func read32(offset: UInt64) -> UInt32? {
        switch offset {
        case 0x00: return width
        case 0x04: return height
        case 0x08: return format
        case 0x0C: return displayEnabled ? 0x01 : 0x00
            
        case 0x1000...:
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex < pixelCount else { return 0 }
            
            // Check store buffer first (forwarding)
            if let value = storeBuffer.lookup(address: baseAddress + offset, size: 4) {
                return UInt32(value & 0xFFFFFFFF)
            }
            
            // Read from front buffer
            return frontBuffer[pixelIndex]
            
        default:
            return 0
        }
    }
    
    func read64(offset: UInt64) -> UInt64? {
        switch offset {
        case 0x1000...:
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex + 1 < pixelCount else { return 0 }
            
            // Check store buffer
            if let value = storeBuffer.lookup(address: baseAddress + offset, size: 8) {
                return value
            }
            
            // Read from front buffer
            let low = UInt64(frontBuffer[pixelIndex])
            let high = UInt64(frontBuffer[pixelIndex + 1])
            return low | (high << 32)
            
        default:
            return nil
        }
    }
    
    // MARK: - Write (to back buffer via store buffer)
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        writeCount += 1
        
        switch offset {
        case 0x0C:
            writeLock.lock()
            displayEnabled = (value & 0x01) != 0
            writeLock.unlock()
            return true
            
        case 0x1000...:
            // Add to store buffer
            storeBuffer.add(address: baseAddress + offset, value: UInt64(value), size: 1)
            return true
            
        default:
            return false
        }
    }
    
    func write32(offset: UInt64, value: UInt32) -> Bool {
        writeCount += 1
        
        switch offset {
        case 0x0C:
            writeLock.lock()
            displayEnabled = (value & 0x01) != 0
            writeLock.unlock()
            return true
            
        case 0x1000...:
            // Add to store buffer
            storeBuffer.add(address: baseAddress + offset, value: UInt64(value), size: 4)
            return true
            
        default:
            return false
        }
    }
    
    func write64(offset: UInt64, value: UInt64) -> Bool {
        writeCount += 1
        
        switch offset {
        case 0x1000...:
            // Add to store buffer
            storeBuffer.add(address: baseAddress + offset, value: value, size: 8)
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Bulk Write (bypasses store buffer for large ops)
    
    func writeBulk(offset: UInt64, data: [UInt32]) -> Bool {
        guard offset >= 0x1000 else { return false }
        
        let startPixelIndex = Int((offset - 0x1000) / 4)
        guard startPixelIndex + data.count <= pixelCount else { return false }
        
        writeLock.lock()
        defer { writeLock.unlock() }
        
        // Write directly to back buffer
        for (i, value) in data.enumerated() {
            backBuffer[startPixelIndex + i] = value
        }
        
        return true
    }
    
    // MARK: - Buffer Management
    
    /// Flush store buffer and swap buffers
    func swap() {
        swapLock.lock()
        defer { swapLock.unlock() }
        
        // Flush pending writes to back buffer
        flushStoreBuffer()
        
        // Atomic swap
        (frontBuffer, backBuffer) = (backBuffer, frontBuffer)
        
        swapCount += 1
        
        // Notify callback with new front buffer
        if let callback = updateCallback {
            let pixels = Array(UnsafeBufferPointer(start: frontBuffer, count: pixelCount))
            callback(pixels, Int(width), Int(height))
        }
    }
    
    /// Flush store buffer to back buffer
    func flushStoreBuffer() {
        // Create temporary device interface for flushing
        class BackBufferDevice: MMIODevice {
            let name = "BackBuffer"
            let baseAddress: UInt64
            let size: UInt64
            unowned let parent: DoubleBufferedFramebuffer
            
            init(parent: DoubleBufferedFramebuffer) {
                self.parent = parent
                self.baseAddress = parent.baseAddress
                self.size = parent.size
            }
            
            func write8(offset: UInt64, value: UInt8) -> Bool {
                let pixelByteOffset = offset - 0x1000
                let pixelIndex = Int(pixelByteOffset / 4)
                let byteInPixel = pixelByteOffset % 4
                
                guard pixelIndex < parent.pixelCount else { return false }
                
                let mask = ~(UInt32(0xFF) << (byteInPixel * 8))
                parent.backBuffer[pixelIndex] = (parent.backBuffer[pixelIndex] & mask) | (UInt32(value) << (byteInPixel * 8))
                return true
            }
            
            func write32(offset: UInt64, value: UInt32) -> Bool {
                let pixelIndex = Int((offset - 0x1000) / 4)
                guard pixelIndex < parent.pixelCount else { return false }
                
                parent.backBuffer[pixelIndex] = value
                return true
            }
            
            func write64(offset: UInt64, value: UInt64) -> Bool {
                let pixelIndex = Int((offset - 0x1000) / 4)
                guard pixelIndex + 1 < parent.pixelCount else { return false }
                
                parent.backBuffer[pixelIndex] = UInt32(value & 0xFFFFFFFF)
                parent.backBuffer[pixelIndex + 1] = UInt32(value >> 32)
                return true
            }
            
            func read8(offset: UInt64) -> UInt8? { return nil }
            func read32(offset: UInt64) -> UInt32? { return nil }
            func read64(offset: UInt64) -> UInt64? { return nil }
        }
        
        let device = BackBufferDevice(parent: self)
        storeBuffer.flush(to: device)
    }
    
    // MARK: - Helper Methods
    
    func clear(color: UInt32 = 0xFF000000) {
        writeLock.lock()
        backBuffer.update(repeating: color, count: pixelCount)
        writeLock.unlock()
    }
    
    func getResolution() -> (width: Int, height: Int) {
        return (Int(width), Int(height))
    }
    
    func getStats() -> (writes: Int, swaps: Int, storeBufferStats: (Int, Int, Int, Double)) {
        return (writeCount, swapCount, storeBuffer.stats())
    }
}
