// Print utilities for Leenux OS

/// Print a static string to UART
func print(_ string: StaticString) {
    UART.puts(string)
}

/// Print a newline
func println() {
    UART.putc(0x0A) // '\n'
}

/// Print a string with newline
func println(_ string: StaticString) {
    print(string)
    println()
}

/// Print a 64-bit hexadecimal value
func printHex(_ value: UInt64) {
    let hexChars: [UInt8] = [
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,  // 0-7
        0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66   // 8-9, a-f
    ]
    
    UART.putc(0x30) // '0'
    UART.putc(0x78) // 'x'
    
    for i in (0..<16).reversed() {
        let nibble = (value >> (i * 4)) & 0xF
        UART.putc(hexChars[Int(nibble)])
    }
}

/// Print a decimal value (simple implementation)
func printDec(_ value: UInt64) {
    if value == 0 {
        UART.putc(0x30) // '0'
        return
    }
    
    var num = value
    var digits: [UInt8] = []
    
    while num > 0 {
        digits.append(UInt8(num % 10) + 0x30)
        num /= 10
    }
    
    for digit in digits.reversed() {
        UART.putc(digit)
    }
}
