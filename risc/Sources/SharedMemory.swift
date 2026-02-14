import Foundation

/// Thread-safe 공유 메모리 + MMIO 디바이스
class SharedMemory {
    private var data: [UInt8]
    private let lock = NSRecursiveLock() // Recursive for batching
    let size: Int
    
    /// MMIO 디바이스들
    private var devices: [MMIODevice] = []
    
    init(size: Int = 8 * 1024 * 1024) {
        self.size = size
        self.data = Array(repeating: 0, count: size)
    }
    
    /// MMIO 디바이스 등록
    func registerDevice(_ device: MMIODevice) {
        lock.lock()
        defer { lock.unlock() }
        devices.append(device)
        print("🔌 Registered MMIO device: \(device.name) at \(String(format: "0x%X", device.baseAddress))")
    }
    
    /// 주소에 해당하는 디바이스 찾기
    private func findDevice(for address: UInt64) -> (device: MMIODevice, offset: UInt64)? {
        for device in devices {
            if device.contains(address: address) {
                let offset = address - device.baseAddress
                return (device, offset)
            }
        }
        return nil
    }
    
    /// 8비트 로드 (MMIO 지원)
    func load8(address: UInt64) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.read8(offset: offset)
        }
        
        // 일반 RAM
        guard address < size else { return nil }
        return data[Int(address)]
    }
    
    /// 16비트 로드 (Little-endian, MMIO 지원)
    func load16(address: UInt64) -> UInt16? {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.read16(offset: offset)
        }
        
        // 일반 RAM
        guard address + 1 < size else { return nil }
        let b0 = UInt16(data[Int(address)])
        let b1 = UInt16(data[Int(address + 1)]) << 8
        return b0 | b1
    }
    
    /// 32비트 로드 (Little-endian, MMIO 지원)
    func load32(address: UInt64) -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.read32(offset: offset)
        }
        
        // 일반 RAM
        guard address + 3 < size else { return nil }
        var result: UInt32 = 0
        for i in 0..<4 {
            result |= UInt32(data[Int(address) + i]) << (i * 8)
        }
        return result
    }
    
    /// 64비트 로드 (Little-endian, MMIO 지원)
    func load64(address: UInt64) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.read64(offset: offset)
        }
        
        // 일반 RAM
        guard address + 7 < size else { return nil }
        var result: UInt64 = 0
        for i in 0..<8 {
            result |= UInt64(data[Int(address) + i]) << (i * 8)
        }
        return result
    }
    
    /// 8비트 저장 (MMIO 지원)
    func store8(address: UInt64, value: UInt8) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            // DEBUG: Log UART writes
            if device.baseAddress == 0x10000000 {
                fputs("[SM:UART:\(value)]", stderr)
                fflush(stderr)
            }
            return device.write8(offset: offset, value: value)
        }
        
        // 일반 RAM
        guard address < size else { return false }
        data[Int(address)] = value
        return true
    }
    
    /// 16비트 저장 (Little-endian, MMIO 지원)
    func store16(address: UInt64, value: UInt16) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.write16(offset: offset, value: value)
        }
        
        // 일반 RAM
        guard address + 1 < size else { return false }
        data[Int(address)] = UInt8(value & 0xFF)
        data[Int(address + 1)] = UInt8((value >> 8) & 0xFF)
        return true
    }
    
    /// 32비트 저장 (Little-endian, MMIO 지원)
    func store32(address: UInt64, value: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.write32(offset: offset, value: value)
        }
        
        // 일반 RAM
        guard address + 3 < size else { return false }
        for i in 0..<4 {
            data[Int(address) + i] = UInt8((value >> (i * 8)) & 0xFF)
        }
        return true
    }
    
    /// 64비트 저장 (Little-endian, MMIO 지원)
    func store64(address: UInt64, value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // MMIO 디바이스 체크
        if let (device, offset) = findDevice(for: address) {
            return device.write64(offset: offset, value: value)
        }
        
        // 일반 RAM
        guard address + 7 < size else { return false }
        for i in 0..<8 {
            data[Int(address) + i] = UInt8((value >> (i * 8)) & 0xFF)
        }
        return true
    }
    
    /// 프로그램 로드
    func loadProgram(at address: UInt64, data programData: [UInt8]) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard address + UInt64(programData.count) <= size else { return false }
        
        for (i, byte) in programData.enumerated() {
            data[Int(address) + i] = byte
        }
        return true
    }
    
    /// 메모리 덤프 (디버깅용)
    func dump(start: UInt64, length: Int) -> [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        
        let end = min(Int(start) + length, size)
        return Array(data[Int(start)..<end])
    }
    /// 배치 실행 (락 유지)
    func batch(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block()
    }
}
    
