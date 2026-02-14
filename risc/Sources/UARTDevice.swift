import Foundation

/// UART 디바이스 (콘솔 입출력)
///
/// 레지스터 맵:
/// ```
/// 0x00: TX Data (Write) - 문자 출력
/// 0x04: RX Data (Read)  - 문자 입력
/// 0x08: Status (Read)   - 상태 레지스터
///       bit 0: TX ready (1 = 전송 가능)
///       bit 1: RX ready (1 = 수신 데이터 있음)
/// ```
///
/// **주의**: 호스트 병렬 실행을 위해 thread-safe 구현
class UARTDevice: MMIODevice {
    let name = "UART"
    let baseAddress = MemoryMap.UART_BASE
    let size = MemoryMap.UART_SIZE
    
    /// 수신 버퍼 (키보드 입력)
    private var rxBuffer: [UInt8] = []
    private let bufferLock = NSLock()
    
    /// 출력 콜백 (호스트로 전달)
    var outputCallback: ((UInt8) -> Void)?
    
    // MARK: - Read (Thread-Safe)
    
    func read8(offset: UInt64) -> UInt8? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        switch offset {
        case 0x00:
            // TX Data (읽기는 의미 없음)
            return 0
            
        case 0x04:
            // RX Data
            return rxBuffer.first ?? 0
            
        case 0x08:
            // Status register
            var status: UInt8 = 0
            status |= 0x01  // TX always ready
            if !rxBuffer.isEmpty {
                status |= 0x02  // RX ready
            }
            return status
            
        default:
            return 0
        }
    }
    
    // MARK: - Write (Thread-Safe)
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        switch offset {
        case 0x00:
            // TX Data
            let char = String(UnicodeScalar(value))
            fputs(char, stderr)
            fflush(stderr)
            return true
            
        case 0x04:
            // RX Data (쓰기는 의미 없음, 하지만 버퍼에 추가로 구현 가능)
            // 호스트에서 키보드 입력을 여기에 넣을 수 있음
            rxBuffer.append(value)
            return true
            
        case 0x08:
            // Status (쓰기 불가)
            return false
            
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods (Thread-Safe)
    
    /// 수신 버퍼에 문자 추가 (키보드 입력)
    func pushInput(_ byte: UInt8) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        rxBuffer.append(byte)
    }
    
    /// 수신 버퍼에 문자열 추가
    func pushInputString(_ str: String) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        for byte in str.utf8 {
            rxBuffer.append(byte)
        }
    }
    
    /// 수신 버퍼에서 문자 제거
    func popInput() -> UInt8? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return rxBuffer.isEmpty ? nil : rxBuffer.removeFirst()
    }
    
    /// 버퍼 클리어
    func clearBuffer() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        rxBuffer.removeAll()
    }
}
