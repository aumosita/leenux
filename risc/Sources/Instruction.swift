import Foundation

/// RISC-V 명령어 타입
enum InstructionType {
    case rType(opcode: UInt8, rd: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, funct7: UInt8)
    case iType(opcode: UInt8, rd: UInt8, funct3: UInt8, rs1: UInt8, imm: Int16)
    case sType(opcode: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, imm: Int16)
    case bType(opcode: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, imm: Int16)
    case uType(opcode: UInt8, rd: UInt8, imm: Int32)
    case jType(opcode: UInt8, rd: UInt8, imm: Int32)
    case rTypeAtomic(opcode: UInt8, rd: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, funct7: UInt8) // A extension
}

/// RISC-V 64I 명령어 디코딩
struct Instruction {
    let raw: UInt32
    let type: InstructionType
    
    init(raw: UInt32) {
        self.raw = raw
        self.type = Instruction.decode(raw: raw)
    }
    
    @inline(__always)
    static func decode(raw: UInt32) -> InstructionType {
        let opcode = UInt8(raw & 0x7F)
        
        switch opcode {
        case 0x33, 0x53: // R-type (OP, OP-FP)
            let rd = UInt8((raw >> 7) & 0x1F)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            let rs2 = UInt8((raw >> 20) & 0x1F)
            let funct7 = UInt8((raw >> 25) & 0x7F)
            return .rType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, rs2: rs2, funct7: funct7)

        case 0x2F: // Atomic (AMO)
            let rd = UInt8((raw >> 7) & 0x1F)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            let rs2 = UInt8((raw >> 20) & 0x1F)
            let funct7 = UInt8((raw >> 25) & 0x7F)
            return .rTypeAtomic(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, rs2: rs2, funct7: funct7)

        case 0x43, 0x47, 0x4B, 0x4F: // R4-type (MADD, MSUB, NMSUB, NMADD) - Decoding as R-Type for now (ignoring rs3)
             // Note: R4-type has rs3 at bits 27-31. Current R-Type struct doesn't support rs3.
             // For basic F/D testing (add, sub, mul, div), this is likely sufficient as they don't use rs3.
             // If FMA is needed later, InstructionType needs to generate .r4Type.
            let rd = UInt8((raw >> 7) & 0x1F)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            let rs2 = UInt8((raw >> 20) & 0x1F)
            let funct7 = UInt8((raw >> 25) & 0x7F)
            return .rType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, rs2: rs2, funct7: funct7)
            
        case 0x13, 0x03, 0x67, 0x73, 0x07: // I-type (OP-IMM, LOAD, JALR, SYSTEM, LOAD-FP)
            let rd = UInt8((raw >> 7) & 0x1F)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            var immVal = UInt16((raw >> 20) & 0xFFF)
            if (immVal & 0x800) != 0 { immVal |= 0xF000 }
            let imm = Int16(bitPattern: immVal)
            return .iType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, imm: imm)
            
        case 0x23, 0x27: // S-type (STORE, STORE-FP)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            let rs2 = UInt8((raw >> 20) & 0x1F)
            let imm7 = UInt16((raw >> 25) & 0x7F)
            let imm5 = UInt16((raw >> 7) & 0x1F)
            var immVal = (imm7 << 5) | imm5
            if (immVal & 0x800) != 0 { immVal |= 0xF000 }
            let imm = Int16(bitPattern: immVal)
            return .sType(opcode: opcode, funct3: funct3, rs1: rs1, rs2: rs2, imm: imm)
            
        case 0x63: // B-type
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            let rs2 = UInt8((raw >> 20) & 0x1F)
            let imm12 = (raw >> 31) & 0x1
            let imm10_5 = (raw >> 25) & 0x3F
            let imm4_1 = (raw >> 8) & 0xF
            let imm11 = (raw >> 7) & 0x1
            var imm32 = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
            // Sign extend from 13-bit to 16-bit
            if (imm32 & 0x1000) != 0 {
                imm32 |= 0xFFFFE000  // Sign extend
            }
            let imm = Int16(bitPattern: UInt16(imm32 & 0xFFFF))
            return .bType(opcode: opcode, funct3: funct3, rs1: rs1, rs2: rs2, imm: imm)
            
        case 0x37, 0x17: // U-type
            let rd = UInt8((raw >> 7) & 0x1F)
            let imm = Int32(bitPattern: (raw & 0xFFFFF000))
            return .uType(opcode: opcode, rd: rd, imm: imm)
            
        case 0x6F: // J-type
            let rd = UInt8((raw >> 7) & 0x1F)
            let imm20 = (raw >> 31) & 0x1
            let imm10_1 = (raw >> 21) & 0x3FF
            let imm11 = (raw >> 20) & 0x1
            let imm19_12 = (raw >> 12) & 0xFF
            var imm = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1)
            // Sign extend 21-bit immediate to 32-bit
            if (imm & 0x100000) != 0 {
                imm |= 0xFFE00000
            }
            return .jType(opcode: opcode, rd: rd, imm: Int32(bitPattern: imm))
            
        default:
            // Unknown opcode, treat as I-type for now
            let rd = UInt8((raw >> 7) & 0x1F)
            let funct3 = UInt8((raw >> 12) & 0x7)
            let rs1 = UInt8((raw >> 15) & 0x1F)
            var immVal = UInt16((raw >> 20) & 0xFFF)
            if (immVal & 0x800) != 0 { immVal |= 0xF000 }
            let imm = Int16(bitPattern: immVal)
            return .iType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, imm: imm)
        }
    }
}
