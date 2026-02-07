import Foundation

/// 키보드 디바이스 (입력 처리)
///
/// 레지스터 맵:
/// ```
/// 0x00: Key Code (Read) - 키 코드 (ASCII 또는 스캔코드)
/// 0x04: Status (Read)
///       bit 0: Key available (1 = 키 입력 있음)
///       bit 1: Key pressed (1 = 키 눌림, 0 = 키 떼짐)
/// 0x08: Modifiers (Read)
///       bit 0: Shift
///       bit 1: Control
///       bit 2: Alt
///       bit 3: Command/Meta
/// 0x0C: Control (Write)
///       bit 0: Clear buffer
/// ```
///
/// **주의**: 호스트 병렬 실행을 위해 thread-safe 구현
class KeyboardDevice: MMIODevice {
    let name = "Keyboard"
    let baseAddress = MemoryMap.KB_BASE
    let size = MemoryMap.KB_SIZE
    
    /// 키 이벤트 구조체
    struct KeyEvent {
        let keyCode: UInt8      // ASCII 또는 스캔코드
        let pressed: Bool       // true = 눌림, false = 떼짐
        let modifiers: UInt8    // Shift, Ctrl, Alt 등
    }
    
    /// 키 입력 버퍼 (FIFO)
    private var keyBuffer: [KeyEvent] = []
    private let bufferLock = NSLock()
    
    /// 최대 버퍼 크기
    private let maxBufferSize = 256
    
    /// 현재 modifier 상태
    private var currentModifiers: UInt8 = 0
    
    init() {}
    
    // MARK: - Read (Thread-Safe)
    
    func read8(offset: UInt64) -> UInt8? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        switch offset {
        case 0x00:
            // Key Code - 버퍼에서 키 읽기 및 제거 via popKeyEvent (Thread safe wrapper used internally?)
            // Actually I should use popKeyEvent logic here but I am inside lock already.
            // Be careful about recursion if I call helper methods that lock.
            // Direct manipulation:
            if !keyBuffer.isEmpty {
                return keyBuffer.removeFirst().keyCode
            }
            return 0
            
        case 0x04:
            // Status
            var status: UInt8 = 0
            if !keyBuffer.isEmpty {
                status |= 0x01  // Key available
            }
            if let event = keyBuffer.first, event.pressed {
                status |= 0x02  // Key pressed
            }
            return status
            
        case 0x08:
            // Modifiers
            return currentModifiers
            
        case 0x0C:
            // Control (read-only)
            return 0
            
        default:
            return 0
        }
    }
    
    // MARK: - Write (Thread-Safe)
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        switch offset {
        case 0x00...0x08:
            // Key Code, Status, Modifiers (read-only)
            return false
            
        case 0x0C:
            // Control
            if (value & 0x01) != 0 {
                // Clear buffer
                keyBuffer.removeAll()
            }
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods (Thread-Safe)
    
    /// 키 이벤트 추가 (호스트에서 호출)
    func pushKeyEvent(keyCode: UInt8, pressed: Bool, modifiers: UInt8 = 0) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // 버퍼가 가득 차면 가장 오래된 이벤트 제거
        if keyBuffer.count >= maxBufferSize {
            keyBuffer.removeFirst()
        }
        
        let event = KeyEvent(keyCode: keyCode, pressed: pressed, modifiers: modifiers)
        keyBuffer.append(event)
        currentModifiers = modifiers
    }
    
    /// ASCII 문자 입력 (간편 메서드)
    func pushChar(_ char: Character) {
        if let ascii = char.asciiValue {
            pushKeyEvent(keyCode: ascii, pressed: true, modifiers: 0)
        }
    }
    
    /// 문자열 입력 (각 문자를 순차적으로)
    func pushString(_ str: String) {
        for char in str {
            pushChar(char)
        }
    }
    
    /// 키 이벤트 팝 (키 읽기 후 제거)
    func popKeyEvent() -> KeyEvent? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        return keyBuffer.isEmpty ? nil : keyBuffer.removeFirst()
    }
    
    /// 버퍼에 있는 키 개수
    func getBufferCount() -> Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return keyBuffer.count
    }
    
    /// 버퍼 클리어
    func clearBuffer() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        keyBuffer.removeAll()
    }
    
    /// 현재 키 확인 (제거하지 않음)
    func peekKey() -> KeyEvent? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return keyBuffer.first
    }
}

// MARK: - Key Code 상수

extension KeyboardDevice {
    /// 특수 키 코드 (ASCII 범위 밖)
    enum SpecialKey: UInt8 {
        case backspace = 0x08
        case tab = 0x09
        case enter = 0x0A
        case escape = 0x1B
        case delete = 0x7F
        
        // 확장 키 (0x80 이상)
        case arrowUp = 0x80
        case arrowDown = 0x81
        case arrowLeft = 0x82
        case arrowRight = 0x83
        
        case f1 = 0x90
        case f2 = 0x91
        case f3 = 0x92
        case f4 = 0x93
        case f5 = 0x94
        case f6 = 0x95
        case f7 = 0x96
        case f8 = 0x97
        case f9 = 0x98
        case f10 = 0x99
        case f11 = 0x9A
        case f12 = 0x9B
        
        case home = 0xA0
        case end = 0xA1
        case pageUp = 0xA2
        case pageDown = 0xA3
        case insert = 0xA4
    }
    
    /// Modifier 비트
    enum Modifier: UInt8 {
        case shift = 0x01
        case control = 0x02
        case alt = 0x04
        case meta = 0x08  // Command/Windows
    }
}
