import Foundation

/// 메모리 매핑 I/O 디바이스 프로토콜
protocol MMIODevice: AnyObject {
    /// 디바이스 이름
    var name: String { get }
    
    /// 디바이스 베이스 주소
    var baseAddress: UInt64 { get }
    
    /// 디바이스 크기
    var size: UInt64 { get }
    
    /// 주소가 이 디바이스 범위 내에 있는지 확인
    func contains(address: UInt64) -> Bool
    
    /// 8비트 읽기
    func read8(offset: UInt64) -> UInt8?
    
    /// 16비트 읽기
    func read16(offset: UInt64) -> UInt16?
    
    /// 32비트 읽기
    func read32(offset: UInt64) -> UInt32?
    
    /// 64비트 읽기
    func read64(offset: UInt64) -> UInt64?
    
    /// 8비트 쓰기
    func write8(offset: UInt64, value: UInt8) -> Bool
    
    /// 16비트 쓰기
    func write16(offset: UInt64, value: UInt16) -> Bool
    
    /// 32비트 쓰기
    func write32(offset: UInt64, value: UInt32) -> Bool
    
    /// 64비트 쓰기
    func write64(offset: UInt64, value: UInt64) -> Bool
}

extension MMIODevice {
    func contains(address: UInt64) -> Bool {
        return address >= baseAddress && address < (baseAddress + size)
    }
    
    /// 기본 구현: 다른 크기 읽기를 8비트로 조합
    func read16(offset: UInt64) -> UInt16? {
        guard let b0 = read8(offset: offset),
              let b1 = read8(offset: offset + 1) else { return nil }
        return UInt16(b0) | (UInt16(b1) << 8)
    }
    
    func read32(offset: UInt64) -> UInt32? {
        guard let b0 = read8(offset: offset),
              let b1 = read8(offset: offset + 1),
              let b2 = read8(offset: offset + 2),
              let b3 = read8(offset: offset + 3) else { return nil }
        return UInt32(b0) | (UInt32(b1) << 8) | (UInt32(b2) << 16) | (UInt32(b3) << 24)
    }
    
    func read64(offset: UInt64) -> UInt64? {
        var result: UInt64 = 0
        for i in 0..<8 {
            guard let byte = read8(offset: offset + UInt64(i)) else { return nil }
            result |= UInt64(byte) << (i * 8)
        }
        return result
    }
    
    /// 기본 구현: 다른 크기 쓰기를 8비트로 분해
    func write16(offset: UInt64, value: UInt16) -> Bool {
        return write8(offset: offset, value: UInt8(value & 0xFF)) &&
               write8(offset: offset + 1, value: UInt8((value >> 8) & 0xFF))
    }
    
    func write32(offset: UInt64, value: UInt32) -> Bool {
        for i in 0..<4 {
            if !write8(offset: offset + UInt64(i), value: UInt8((value >> (i * 8)) & 0xFF)) {
                return false
            }
        }
        return true
    }
    
    func write64(offset: UInt64, value: UInt64) -> Bool {
        for i in 0..<8 {
            if !write8(offset: offset + UInt64(i), value: UInt8((value >> (i * 8)) & 0xFF)) {
                return false
            }
        }
        return true
    }
}

/// 메모리 맵 정의
enum MemoryMap {
    // RAM
    static let RAM_START:     UInt64 = 0x0000_0000
    static let RAM_SIZE:      UInt64 = 0x4000_0000  // 1GB
    
    // MMIO 디바이스들
    static let UART_BASE:     UInt64 = 0x1000_0000
    static let UART_SIZE:     UInt64 = 0x1000       // 4KB
    
    static let TIMER_BASE:    UInt64 = 0x1000_1000
    static let TIMER_SIZE:    UInt64 = 0x1000       // 4KB
    
    static let INTC_BASE:     UInt64 = 0x1000_2000  // Interrupt Controller (미래)
    static let INTC_SIZE:     UInt64 = 0x1000       // 4KB
    
    static let FB_BASE:       UInt64 = 0x1000_3000  // Framebuffer
    static let FB_SIZE:       UInt64 = 0x0400_0000  // 64MB (여러 해상도 지원)
    
    static let KB_BASE:       UInt64 = 0x1400_0000  // Keyboard
    static let KB_SIZE:       UInt64 = 0x1000       // 4KB
}
