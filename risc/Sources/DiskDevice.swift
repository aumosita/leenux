import Foundation

/// Disk Device backed by a host file
#if os(macOS)
@available(macOS 10.15.4, *)
#endif
class DiskDevice: MMIODevice {
    let name = "Disk"
    let baseAddress: UInt64 = 0x1500_0000
    let size: UInt64 = 0x100  // Registers only
    
    // Registers
    // 0x00: Sector Number (4 bytes)
    // 0x04: Buffer Address (4 bytes)
    // 0x08: Command (1 byte)
    // 0x0C: Status (1 byte)
    
    private var sectorNumber: UInt32 = 0
    private var bufferAddress: UInt32 = 0
    private var status: UInt8 = 0
    
    private let fileHandle: FileHandle?
    private let memory: SharedMemory
    
    init(memory: SharedMemory, imagePath: String = "disk.img") {
        self.memory = memory
        
        // Open disk image
        if FileManager.default.fileExists(atPath: imagePath) {
            self.fileHandle = FileHandle(forUpdatingAtPath: imagePath)
        } else {
            print("⚠️ Disk image not found at \(imagePath). Disk will be read-only/volatile.")
            self.fileHandle = nil
        }
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    // MARK: - MMIODevice Protocol
    
    func read8(offset: UInt64) -> UInt8? {
        switch offset {
        case 0x00: return UInt8(sectorNumber & 0xFF)
        case 0x01: return UInt8((sectorNumber >> 8) & 0xFF)
        case 0x02: return UInt8((sectorNumber >> 16) & 0xFF)
        case 0x03: return UInt8((sectorNumber >> 24) & 0xFF)
            
        case 0x04: return UInt8(bufferAddress & 0xFF)
        case 0x05: return UInt8((bufferAddress >> 8) & 0xFF)
        case 0x06: return UInt8((bufferAddress >> 16) & 0xFF)
        case 0x07: return UInt8((bufferAddress >> 24) & 0xFF)
            
        case 0x0C: return status
            
        default: return 0
        }
    }
    
    func write8(offset: UInt64, value: UInt8) -> Bool {
        switch offset {
        case 0x00: sectorNumber = (sectorNumber & 0xFFFFFF00) | UInt32(value)
        case 0x01: sectorNumber = (sectorNumber & 0xFFFF00FF) | (UInt32(value) << 8)
        case 0x02: sectorNumber = (sectorNumber & 0xFF00FFFF) | (UInt32(value) << 16)
        case 0x03: sectorNumber = (sectorNumber & 0x00FFFFFF) | (UInt32(value) << 24)
            
        case 0x04: bufferAddress = (bufferAddress & 0xFFFFFF00) | UInt32(value)
        case 0x05: bufferAddress = (bufferAddress & 0xFFFF00FF) | (UInt32(value) << 8)
        case 0x06: bufferAddress = (bufferAddress & 0xFF00FFFF) | (UInt32(value) << 16)
        case 0x07: bufferAddress = (bufferAddress & 0x00FFFFFF) | (UInt32(value) << 24)
            
        case 0x08: executeCommand(value)
            
        default: break
        }
        return true
    }
    
    private func executeCommand(_ command: UInt8) {
        status = 1 // Busy
        
        guard let handle = fileHandle else {
            status = 0xFF // Error
            return
        }
        
        let fileOffset = UInt64(sectorNumber) * 512
        
        do {
            try handle.seek(toOffset: fileOffset)
            
            if command == 1 { // READ
                let data = handle.readData(ofLength: 512)
                if data.count == 512 {
                    // Write to memory
                    for (i, byte) in data.enumerated() {
                        _ = memory.store8(address: UInt64(bufferAddress) + UInt64(i), value: byte)
                    }
                    status = 2 // Done
                } else {
                    status = 0xFF // Error
                }
            } else if command == 2 { // WRITE
                // Read from memory
                var data = Data(count: 512)
                for i in 0..<512 {
                    if let byte = memory.load8(address: UInt64(bufferAddress) + UInt64(i)) {
                        data[i] = byte
                    }
                }
                handle.write(data)
                try handle.synchronize() // Ensure write to disk
                status = 2 // Done
            } else {
                status = 0xFF
            }
        } catch {
            print("Disk Error: \(error)")
            status = 0xFF
        }
    }
}
