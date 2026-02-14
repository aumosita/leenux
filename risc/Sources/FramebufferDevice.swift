import Foundation

/// 프레임버퍼 디바이스 (화면 출력)
///
/// 메모리 맵:
/// ```
/// 0x00-0x03: Width (32-bit)
/// 0x04-0x07: Height (32-bit)
/// 0x08-0x0B: Format (32-bit)
///            0 = ARGB8888 (32-bit per pixel)
///            1 = RGB565 (16-bit per pixel)
/// 0x0C-0x0F: Control (32-bit)
///            bit 0: Display enabled
///            bit 1: VSync (read-only)
/// 0x1000+:   Pixel data
///            ARGB8888: width * height * 4 bytes
/// ```
///
/// **주의**: 호스트 병렬 실행을 위해 thread-safe 구현
class FramebufferDevice: MMIODevice {
    let name = "Framebuffer"
    let baseAddress = MemoryMap.FB_BASE
    let size = MemoryMap.FB_SIZE
    
    /// 화면 너비
    private var width: UInt32 = 1024
    
    /// 화면 높이
    private var height: UInt32 = 768
    
    /// 픽셀 포맷 (0 = ARGB8888)
    private var format: UInt32 = 0
    
    /// 디스플레이 활성화
    private var displayEnabled: Bool = true
    
    /// 픽셀 데이터 (ARGB8888)
    private var pixels: [UInt32]
    
    /// Thread-safety를 위한 락
    private let lock = NSLock()
    
    /// 업데이트 콜백 (호스트 GUI 업데이트용)
    var updateCallback: (([UInt32], Int, Int) -> Void)?
    
    /// Dirty flag (업데이트 최적화)
    private var isDirty: Bool = false
    
    init(width: Int = 1024, height: Int = 768) {
        self.width = UInt32(width)
        self.height = UInt32(height)
        self.pixels = Array(repeating: 0xFF000000, count: width * height)  // 검은색
    }
    
    /// 픽셀 오프셋 계산
    private func pixelOffset(x: Int, y: Int) -> Int? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        return y * Int(width) + x
    }
    
    // MARK: - Read (Thread-Safe)
    
    func read8(offset: UInt64) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x00...0x03:
            // Width (32-bit)
            let byteIndex = offset - 0x00
            return UInt8((width >> (byteIndex * 8)) & 0xFF)
            
        case 0x04...0x07:
            // Height (32-bit)
            let byteIndex = offset - 0x04
            return UInt8((height >> (byteIndex * 8)) & 0xFF)
            
        case 0x08...0x0B:
            // Format (32-bit)
            let byteIndex = offset - 0x08
            return UInt8((format >> (byteIndex * 8)) & 0xFF)
            
        case 0x0C...0x0F:
            // Control (32-bit)
            let byteIndex = offset - 0x0C
            var control: UInt32 = 0
            if displayEnabled {
                control |= 0x01
            }
            // VSync bit는 항상 0 (간단한 구현)
            return UInt8((control >> (byteIndex * 8)) & 0xFF)
            
        case 0x1000...:
            // Pixel data
            let pixelByteOffset = offset - 0x1000
            let pixelIndex = Int(pixelByteOffset / 4)
            let byteInPixel = pixelByteOffset % 4
            
            guard pixelIndex < pixels.count else { return 0 }
            let pixel = pixels[pixelIndex]
            return UInt8((pixel >> (byteInPixel * 8)) & 0xFF)
            
        default:
            return 0
        }
    }
    
    func read32(offset: UInt64) -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x00:
            return width
            
        case 0x04:
            return height
            
        case 0x08:
            return format
            
        case 0x0C:
            var control: UInt32 = 0
            if displayEnabled {
                control |= 0x01
            }
            return control
            
        case 0x1000...:
            // Pixel data (4바이트 정렬된 읽기)
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex < pixels.count else { return 0 }
            return pixels[pixelIndex]
            
        default:
            return 0
        }
    }

    func read64(offset: UInt64) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x1000...:
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex + 1 < pixels.count else { return 0 }
            let low = UInt64(pixels[pixelIndex])
            let high = UInt64(pixels[pixelIndex + 1])
            return low | (high << 32)
        default:
            return nil
        }
    }
    
    // MARK: - Write (Thread-Safe)
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x00...0x03:
            // Width (read-only for now)
            return false
            
        case 0x04...0x07:
            // Height (read-only for now)
            return false
            
        case 0x08...0x0B:
            // Format (read-only for now)
            return false
            
        case 0x0C...0x0F:
            // Control
            if offset == 0x0C {
                displayEnabled = (value & 0x01) != 0
            }
            return true
            
        case 0x1000...:
            // Pixel data (byte write)
            let pixelByteOffset = offset - 0x1000
            let pixelIndex = Int(pixelByteOffset / 4)
            let byteInPixel = pixelByteOffset % 4
            
            guard pixelIndex < pixels.count else { return false }
            
            let mask = ~(UInt32(0xFF) << (byteInPixel * 8))
            pixels[pixelIndex] = (pixels[pixelIndex] & mask) | (UInt32(value) << (byteInPixel * 8))
            
            isDirty = true
            return true
            
        default:
            return false
        }
    }
    
    func write32(offset: UInt64, value: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x0C:
            // Control
            displayEnabled = (value & 0x01) != 0
            return true
            
        case 0x1000...:
            // Pixel data (32-bit write, 더 효율적)
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex < pixels.count else { return false }
            pixels[pixelIndex] = value
            isDirty = true
            return true
            
        default:
            return false
        }
    }

    func write64(offset: UInt64, value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch offset {
        case 0x1000...:
            // Pixel data (64-bit write, 2 pixels at once)
            let pixelIndex = Int((offset - 0x1000) / 4)
            guard pixelIndex + 1 < pixels.count else { return false }
            pixels[pixelIndex] = UInt32(value & 0xFFFFFFFF)
            pixels[pixelIndex + 1] = UInt32(value >> 32)
            isDirty = true
            return true
            
        default:
            // Fallback or specific MMIO registers if needed
            return false
        }
    }
    
    // MARK: - Helper Methods (Thread-Safe)
    
    /// 특정 픽셀 설정
    func setPixel(x: Int, y: Int, color: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let index = pixelOffset(x: x, y: y) else { return false }
        pixels[index] = color
        isDirty = true
        return true
    }
    
    /// 특정 픽셀 읽기
    func getPixel(x: Int, y: Int) -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let index = pixelOffset(x: x, y: y) else { return nil }
        return pixels[index]
    }
    
    /// 사각형 채우기
    func fillRect(x: Int, y: Int, width fillWidth: Int, height fillHeight: Int, color: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        
        for dy in 0..<fillHeight {
            for dx in 0..<fillWidth {
                if let index = pixelOffset(x: x + dx, y: y + dy) {
                    pixels[index] = color
                }
            }
        }
        isDirty = true
    }
    
    /// 화면 전체 클리어
    func clear(color: UInt32 = 0xFF000000) {
        lock.lock()
        defer { lock.unlock() }
        
        pixels = Array(repeating: color, count: pixels.count)
        isDirty = true
    }
    
    /// 프레임버퍼 업데이트 (호스트 GUI로 전달)
    func flush() {
        lock.lock()
        defer { lock.unlock() }
        
        if isDirty, let callback = updateCallback {
            callback(pixels, Int(width), Int(height))
            isDirty = false
        }
    }
    
    /// 픽셀 데이터 직접 접근 (복사본 반환)
    func getPixels() -> [UInt32] {
        lock.lock()
        defer { lock.unlock() }
        return pixels
    }
    
    /// 해상도 정보
    func getResolution() -> (width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (Int(width), Int(height))
    }
}
