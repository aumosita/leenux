// UART Driver for Leenux OS
// Memory-mapped I/O for UART communication at 0x10000000

struct UART {
    static let baseAddress: UInt64 = 0x10000000
    
    /// Write a single character to UART
    static func putc(_ char: UInt8) {
        let ptr = UnsafeMutablePointer<UInt8>(bitPattern: UInt(baseAddress))!
        ptr.pointee = char
    }
    
    /// Write a string to UART
    static func puts(_ string: StaticString) {
        string.utf8Start.withMemoryRebound(to: UInt8.self, capacity: string.utf8CodeUnitCount) { ptr in
            for i in 0..<string.utf8CodeUnitCount {
                putc(ptr[i])
            }
        }
    }
}
