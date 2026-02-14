import Foundation

/// 타이머 디바이스 (사이클 기반)
///
/// 레지스터 맵:
/// ```
/// 0x00-0x07: Current Cycle (64-bit) - 에뮬레이터 사이클 카운트
/// 0x08-0x0F: Alarm Cycle (64-bit) - 알람 트리거 사이클
/// 0x10:      Control Register
///            bit 0: Alarm enable
///            bit 1: Alarm triggered (read-only)
/// 0x18-0x1F: Frequency (64-bit, read-only) - Hz (기본: 1MHz 가상 주파수)
/// ```
///
/// **주의**: 호스트 병렬 실행을 위해 thread-safe 구현 필요
class TimerDevice: MMIODevice {
    let name = "Timer"
    let baseAddress = MemoryMap.TIMER_BASE
    let size = MemoryMap.TIMER_SIZE
    
    /// 현재 사이클 (atomic access 필요)
    private var currentCycle: UInt64 = 0
    private let cycleLock = NSLock()
    
    /// 알람 사이클
    private var alarmCycle: UInt64 = 0
    
    /// 알람 활성화
    private var alarmEnabled: Bool = false
    
    /// 알람 트리거됨
    private var alarmTriggered: Bool = false
    
    /// 가상 주파수 (Hz) - OS가 시간 계산에 사용
    let frequency: UInt64 = 1_000_000  // 1MHz
    
    /// Interrupt Callback (active)
    var onInterrupt: ((Bool) -> Void)?
    
    init() {
        self.currentCycle = 0
    }
    
    // MARK: - Read
    
    func read8(offset: UInt64) -> UInt8? {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        
        switch offset {
        case 0x00...0x07:
            // Current Cycle (64-bit)
            let byteIndex = offset - 0x00
            return UInt8((currentCycle >> (byteIndex * 8)) & 0xFF)
            
        case 0x08...0x0F:
            // Alarm Cycle (64-bit)
            let byteIndex = offset - 0x08
            return UInt8((alarmCycle >> (byteIndex * 8)) & 0xFF)
            
        case 0x10:
            // Control Register
            var control: UInt8 = 0
            if alarmEnabled {
                control |= 0x01
            }
            if alarmTriggered {
                control |= 0x02
            }
            return control
            
        case 0x18...0x1F:
            // Frequency (64-bit, read-only)
            let byteIndex = offset - 0x18
            return UInt8((frequency >> (byteIndex * 8)) & 0xFF)
            
        default:
            return 0
        }
    }
    
    func read64(offset: UInt64) -> UInt64? {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        
        switch offset {
        case 0x00:
            return currentCycle
            
        case 0x08:
            return alarmCycle
            
        case 0x18:
            return frequency
            
        default:
            // 기본 구현 사용
            var result: UInt64 = 0
            for i in 0..<8 {
                guard let byte = read8(offset: offset + UInt64(i)) else { return nil }
                result |= UInt64(byte) << (i * 8)
            }
            return result
        }
    }
    
    // MARK: - Write
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        
        switch offset {
        case 0x00...0x07:
            // Current Cycle (read-only)
            return false
            
        case 0x08...0x0F:
            // Alarm Cycle (64-bit write)
            let byteIndex = offset - 0x08
            let mask = ~(UInt64(0xFF) << (byteIndex * 8))
            alarmCycle = (alarmCycle & mask) | (UInt64(value) << (byteIndex * 8))
            return true
            
        case 0x10:
            // Control Register
            alarmEnabled = (value & 0x01) != 0
            
            // bit 1 쓰기로 알람 클리어
            if (value & 0x02) != 0 {
                alarmTriggered = false
            }
            return true
            
        case 0x18...0x1F:
            // Frequency (read-only)
            return false
            
        default:
            return false
        }
    }
    
    func write64(offset: UInt64, value: UInt64) -> Bool {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        
        switch offset {
        case 0x08:
            // Alarm Cycle
            alarmCycle = value
            return true
            
        default:
            // 기본 구현 사용
            for i in 0..<8 {
                if !write8(offset: offset + UInt64(i), value: UInt8((value >> (i * 8)) & 0xFF)) {
                    return false
                }
            }
            return true
        }
    }
    
    // MARK: - Helper Methods (Thread-Safe)
    
    /// 사이클 증가 (매 사이클 호출)
    func tick() {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        
        currentCycle += 1
        
        // 알람 체크
        if alarmEnabled {
            if currentCycle >= alarmCycle {
                if !alarmTriggered {
                    alarmTriggered = true
                    onInterrupt?(true) // Assert Interrupt
                }
            } else {
                 if alarmTriggered {
                     alarmTriggered = false
                     onInterrupt?(false) // De-assert
                 }
            }
        } else {
             if alarmTriggered {
                 alarmTriggered = false
                 onInterrupt?(false)
             }
        }
    }
    
    /// 현재 사이클 읽기 (thread-safe)
    func getCycle() -> UInt64 {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        return currentCycle
    }
    
    /// 사이클 리셋 (테스트용)
    func reset() {
        cycleLock.lock()
        defer { cycleLock.unlock() }
        currentCycle = 0
        alarmTriggered = false
    }
}
