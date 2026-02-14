import Foundation

/// Shared Memory Command Queue Device
/// 
/// MMIO device that provides command queue interface
/// for inter-core communication (thread-safe)
class CommandQueueDevice: MMIODevice {
    let name = "CommandQueue"
    let baseAddress: UInt64 = 0x20000000
    let size: UInt64 = 0x1000  // 4KB
    
    // Command structure (16 bytes) - thread-safe with lock
    private var commandType: UInt32 = 0
    private var arg0: UInt32 = 0
    private var arg1: UInt32 = 0
    private var arg2: UInt32 = 0
    
    private let lock = NSLock()
    
    func contains(address: UInt64) -> Bool {
        return address >= baseAddress && address < baseAddress + size
    }
    
    // MARK: - Read
    
    func read8(offset: UInt64) -> UInt8? {
        guard let val = read32(offset: offset & ~3) else { return nil }
        let byteOffset = offset & 3
        return UInt8((val >> (byteOffset * 8)) & 0xFF)
    }
    
    func read16(offset: UInt64) -> UInt16? {
        guard let val = read32(offset: offset & ~3) else { return nil }
        let byteOffset = offset & 3
        return UInt16((val >> (byteOffset * 8)) & 0xFFFF)
    }
    
    func read32(offset: UInt64) -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        
        let val: UInt32
        switch offset {
        case 0x00: val = commandType
        case 0x04: val = arg0
        case 0x08: val = arg1
        case 0x0C: val = arg2
        default: val = 0
        }
        
        return val
    }
    
    func read64(offset: UInt64) -> UInt64? {
        guard let low = read32(offset: offset) else { return nil }
        guard let high = read32(offset: offset + 4) else { return nil }
        return UInt64(low) | (UInt64(high) << 32)
    }
    
    // MARK: - Write
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        guard let current = read32(offset: offset & ~3) else { return false }
        let byteOffset = offset & 3
        let mask = ~(UInt32(0xFF) << (byteOffset * 8))
        let newValue = (current & mask) | (UInt32(value) << (byteOffset * 8))
        return write32(offset: offset & ~3, value: newValue)
    }
    
    func write16(offset: UInt64, value: UInt16) -> Bool {
        guard let current = read32(offset: offset & ~3) else { return false }
        let byteOffset = offset & 3
        let mask = ~(UInt32(0xFFFF) << (byteOffset * 8))
        let newValue = (current & mask) | (UInt32(value) << (byteOffset * 8))
        return write32(offset: offset & ~3, value: newValue)
    }
    
    func write32(offset: UInt64, value: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x00:
            commandType = value
        case 0x04:
            arg0 = value
        case 0x08:
            arg1 = value
        case 0x0C:
            arg2 = value
        default:
            break
        }
        return true
    }
    
    func write64(offset: UInt64, value: UInt64) -> Bool {
        let low = UInt32(value & 0xFFFFFFFF)
        let high = UInt32((value >> 32) & 0xFFFFFFFF)
        return write32(offset: offset, value: low) && 
               write32(offset: offset + 4, value: high)
    }
}
