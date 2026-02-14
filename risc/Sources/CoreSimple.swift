import Foundation

/// RISC-V 64I 단일 코어 (순차 실행 - Sequential Execution)
///
/// 파이프라인 없이 각 명령어를 완전히 실행한 후 다음 명령어로 진행
/// 간단하고 디버깅이 쉬운 구조
struct CoreSimpleState {
    var pc: UInt64
    var registers: [UInt64]
    var fpRegisters: [Double]
    var fcsr: UInt32
    var csr: [Int: UInt64]
    
    // Execution Stats & Flags
    var cyclesExecuted: Int
    var instructionsExecuted: Int
    var halted: Bool
    
    // Atomic
    var loadReservation: UInt64?
    
    init(startPC: UInt64) {
        self.pc = startPC
        self.registers = Array(repeating: 0, count: 32)
        self.fpRegisters = Array(repeating: 0.0, count: 32)
        self.fcsr = 0
        self.csr = [:]
        self.cyclesExecuted = 0
        self.instructionsExecuted = 0
        self.halted = false
        self.loadReservation = nil
    }
}

class CoreSimple {
    // MARK: - Properties
    
    let id: Int
    var state: CoreSimpleState
    var debug: Bool = false
    
    var pendingStepResult: StepResult? = nil
    
    /// 메모리 버스
    unowned let memoryBus: MemoryBus
    
    /// L1 Cache
    var l1Cache: L1Cache?
    let enableCache: Bool
    
    // 편의 속성
    var pc: UInt64 {
        get { state.pc }
        set { state.pc = newValue }
    }
    
    var registers: [UInt64] {
        get { state.registers }
        set { state.registers = newValue }
    }
    
    var fpRegisters: [Double] {
        get { state.fpRegisters }
        set { state.fpRegisters = newValue }
    }
    
    var halted: Bool {
        get { state.halted }
        set { state.halted = newValue }
    }
    
    var cyclesExecuted: Int {
        get { state.cyclesExecuted }
        set { state.cyclesExecuted = newValue }
    }
    
    var instructionsExecuted: Int {
        get { state.instructionsExecuted }
        set { state.instructionsExecuted = newValue }
    }
    
    var loadReservation: UInt64? {
        get { state.loadReservation }
        set { state.loadReservation = newValue }
    }
    
    // 통계
    var branchesTaken: Int = 0
    var branchesNotTaken: Int = 0
    var stallsDetected: Int = 0
    var branchMispredictions: Int = 0
    var branchPredictor = TwoBitBranchPredictor()
    
    // MARK: - Initialization
    
    init(id: Int, memoryBus: MemoryBus, startPC: UInt64 = 0x1000, enableCache: Bool = true) {
        self.id = id
        self.memoryBus = memoryBus
        self.enableCache = enableCache
        self.state = CoreSimpleState(startPC: startPC)
        
        if enableCache {
            self.l1Cache = L1Cache()
        }
    }
    
    // MARK: - 순차 실행
    
    /// 한 사이클 실행 (한 명령어를 완전히 실행)
    func tick() {
        guard !halted else { return }
        
        // 0. Check Interrupts
        if let cause = checkInterrupts() {
            enterTrap(cause: cause, isInterrupt: true)
            // Trap takes a cycle
            cyclesExecuted += 1
            return
        }
        
        cyclesExecuted += 1
        
        // 1. Fetch
        guard let instruction = fetch() else {
            if debug { print("[Core \(id)] Fetch failed at PC=0x\(String(format: "%X", pc))") }
            return
        }
        
        if debug {
            print("[Core \(id)] PC=0x\(String(format: "%X", pc)), Instr=0x\(String(format: "%08X", instruction))")
        }
        
        let instrPC = pc
        pc += 4  // PC 증가
        
        // 2. Decode & Execute
        executeInstruction(instruction, at: instrPC)
        
        // x0는 항상 0
        registers[0] = 0
    }
    
    // MARK: - Fetch
    
    /// 명령어 Fetch (동기)
    private func fetch() -> UInt32? {
        if let val = memoryBus.read32(coreId: id, address: pc) {
            return val
        }
        return nil
    }
    
    // MARK: - Decode & Execute
    
    /// 명령어 디코딩 및 실행
    private func executeInstruction(_ raw: UInt32, at instrPC: UInt64) {
        let decoded = Instruction.decode(raw: raw)
        
        switch decoded {
        case .rType(let opcode, let rd, let funct3, let rs1, let rs2, let funct7):
            executeRType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, rs2: rs2, funct7: funct7)
            
        case .iType(let opcode, let rd, let funct3, let rs1, let imm):
            executeIType(opcode: opcode, rd: rd, funct3: funct3, rs1: rs1, imm: imm, pc: instrPC)
            
        case .sType(let opcode, let funct3, let rs1, let rs2, let imm):
            executeSType(opcode: opcode, funct3: funct3, rs1: rs1, rs2: rs2, imm: imm)
            
        case .bType(let _, let funct3, let rs1, let rs2, let imm):
            executeBType(funct3: funct3, rs1: rs1, rs2: rs2, imm: imm, pc: instrPC)
            
        case .uType(let opcode, let rd, let imm):
            executeUType(opcode: opcode, rd: rd, imm: imm, pc: instrPC)
            
        case .jType(let _, let rd, let imm):
            executeJType(rd: rd, imm: imm, pc: instrPC)
            
        case .rTypeAtomic(let _, let rd, let funct3, let rs1, let rs2, let funct7):
            executeAtomic(rd: rd, funct3: funct3, rs1: rs1, rs2: rs2, funct7: funct7)
        }
    }
    
    // MARK: - R-Type
    
    private func executeRType(opcode: UInt8, rd: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, funct7: UInt8) {
        let a = registers[Int(rs1)]
        let b = registers[Int(rs2)]
        var result: UInt64 = 0
        
        // ALU 연산
        switch (funct7, funct3) {
        case (0x00, 0x0): result = a &+ b  // ADD
        case (0x20, 0x0): result = a &- b  // SUB
        case (0x00, 0x4): result = a ^ b   // XOR
        case (0x00, 0x6): result = a | b   // OR
        case (0x00, 0x7): result = a & b   // AND
        case (0x00, 0x1): result = a << (b & 0x3F)  // SLL
        case (0x00, 0x5): result = a >> (b & 0x3F)  // SRL
        case (0x20, 0x5): result = UInt64(bitPattern: Int64(bitPattern: a) >> Int(b & 0x3F))  // SRA
        case (0x00, 0x2): result = Int64(bitPattern: a) < Int64(bitPattern: b) ? 1 : 0  // SLT
        case (0x00, 0x3): result = a < b ? 1 : 0  // SLTU
            
        // M Extension
        case (0x01, 0x0): result = a &* b  // MUL
        case (0x01, 0x4):  // DIV
            if b == 0 {
                result = UInt64.max
            } else {
                let aInt = Int64(bitPattern: a)
                let bInt = Int64(bitPattern: b)
                if aInt == Int64.min && bInt == -1 {
                    result = UInt64(bitPattern: Int64.min)
                } else {
                    result = UInt64(bitPattern: aInt / bInt)
                }
            }
        case (0x01, 0x5):  // DIVU
            result = b == 0 ? UInt64.max : a / b
        case (0x01, 0x6):  // REM
            if b == 0 {
                result = a
            } else {
                let aInt = Int64(bitPattern: a)
                let bInt = Int64(bitPattern: b)
                if aInt == Int64.min && bInt == -1 {
                    result = 0
                } else {
                    result = UInt64(bitPattern: aInt % bInt)
                }
            }
        case (0x01, 0x7):  // REMU
            result = b == 0 ? a : a % b
            
        default:
            if debug { print("[Core \(id)] Unknown R-type: funct7=0x\(String(format: "%02X", funct7)), funct3=0x\(String(format: "%X", funct3))") }
            return
        }
        
        if rd != 0 {
            registers[Int(rd)] = result
        }
        instructionsExecuted += 1
    }
    
    // MARK: - I-Type
    
    private func executeIType(opcode: UInt8, rd: UInt8, funct3: UInt8, rs1: UInt8, imm: Int16, pc: UInt64) {
        let immediate = Int64(imm)
        
        switch opcode {
        case 0x13:  // OP-IMM
            let a = registers[Int(rs1)]
            let b = UInt64(bitPattern: immediate)
            var result: UInt64 = 0
            
            switch funct3 {
            case 0x0: result = a &+ b  // ADDI
            case 0x4: result = a ^ b   // XORI
            case 0x6: result = a | b   // ORI
            case 0x7: result = a & b   // ANDI
            case 0x1: result = a << (b & 0x3F)  // SLLI
            case 0x5:  // SRLI/SRAI
                if (imm & 0x400) != 0 {
                    result = UInt64(bitPattern: Int64(bitPattern: a) >> Int(b & 0x3F))  // SRAI
                } else {
                    result = a >> (b & 0x3F)  // SRLI
                }
            case 0x2: result = Int64(bitPattern: a) < immediate ? 1 : 0  // SLTI
            case 0x3: result = a < b ? 1 : 0  // SLTIU
            default: return
            }
            
            if rd != 0 {
                registers[Int(rd)] = result
            }
            instructionsExecuted += 1
            
        case 0x03:  // LOAD
            let address = registers[Int(rs1)] &+ UInt64(bitPattern: immediate)
            let memSize = funct3 & 0x3
            let memSigned = (funct3 & 0x4) == 0
            var value: UInt64 = 0
            
            switch memSize {
            case 0:  // LB/LBU
                if let val = memoryBus.read8(coreId: id, address: address) {
                    value = memSigned ? UInt64(bitPattern: Int64(Int8(bitPattern: val))) : UInt64(val)
                }
            case 1:  // LH/LHU
                if let val = memoryBus.read16(coreId: id, address: address) {
                    value = memSigned ? UInt64(bitPattern: Int64(Int16(bitPattern: val))) : UInt64(val)
                }
            case 2:  // LW/LWU
                if let val = memoryBus.read32(coreId: id, address: address) {
                    value = memSigned ? UInt64(bitPattern: Int64(Int32(bitPattern: val))) : UInt64(val)
                }
            case 3:  // LD
                if let val = memoryBus.read64(coreId: id, address: address) {
                    value = val
                }
            default: break
            }
            
            if rd != 0 {
                registers[Int(rd)] = value
            }
            instructionsExecuted += 1
            
        case 0x67:  // JALR
            let address = registers[Int(rs1)] &+ UInt64(bitPattern: immediate)
            if rd != 0 {
                registers[Int(rd)] = pc + 4  // 다음 명령어 주소 저장
            }
            self.pc = address & ~1  // 최하위 비트 클리어
            instructionsExecuted += 1
            
        case 0x73:  // SYSTEM
            if imm == 1 {
                // EBREAK
                halted = true
                pendingStepResult = .exit
                instructionsExecuted += 1
            } else if imm == 0 {
                // ECALL
                pendingStepResult = .yield
                instructionsExecuted += 1
            } else {
                // CSR Instructions (funct3 != 0)
                let csr = Int(UInt16(bitPattern: imm)) & 0xFFF
                let uimm = UInt64(rs1) // For immediate variants, rs1 field holds the immediate (zimm)
                let rs1Val = registers[Int(rs1)]
                
                var t: UInt64 = 0
                let shouldRead = (rd != 0)
                
                // Read CSR if needed (or for Swap/Set/Clear where read is implicit)
                // Note: CSRRW with rd=x0 doesn't strictly need read, but we can simplify
                if shouldRead || funct3 != 1 { // funct3=1 is CSRRW (Write) - Read only if rd!=0
                     t = getCSR(csr)
                }
                
                var newVal = t
                var write = true
                
                switch funct3 {
                case 1: // CSRRW
                    newVal = rs1Val
                case 2: // CSRRS
                    newVal = t | rs1Val
                    if rs1 == 0 { write = false } // Reading without side effects if rs1=0
                case 3: // CSRRC
                    newVal = t & ~rs1Val
                    if rs1 == 0 { write = false }
                    
                case 5: // CSRRWI
                    newVal = uimm
                case 6: // CSRRSI
                    newVal = t | uimm
                    if uimm == 0 { write = false }
                case 7: // CSRRCI
                    newVal = t & ~uimm
                    if uimm == 0 { write = false }
                    
                default:
                    write = false
                }
                
                if write {
                    setCSR(csr, value: newVal)
                }
                
                if shouldRead {
                    registers[Int(rd)] = t
                }
                
                instructionsExecuted += 1
            }
            
        case 0x07:  // LOAD-FP
            let address = registers[Int(rs1)] &+ UInt64(bitPattern: immediate)
            let memSize = funct3 & 0x3
            
            if memSize == 2 {  // FLW
                if let bits = memoryBus.read32(coreId: id, address: address) {
                    fpRegisters[Int(rd)] = Double(Float(bitPattern: bits))
                }
            } else if memSize == 3 {  // FLD
                if let bits = memoryBus.read64(coreId: id, address: address) {
                    fpRegisters[Int(rd)] = Double(bitPattern: bits)
                }
            }
            instructionsExecuted += 1
            
        default:
            if debug { print("[Core \(id)] Unknown I-type opcode: 0x\(String(format: "%02X", opcode))") }
        }
    }
    
    // MARK: - S-Type
    
    private func executeSType(opcode: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, imm: Int16) {
        let address = registers[Int(rs1)] &+ UInt64(bitPattern: Int64(imm))
        let memSize = funct3 & 0x3
        
        if opcode == 0x23 {  // STORE
            let value = registers[Int(rs2)]
            
            switch memSize {
            case 0:  // SB
                _ = memoryBus.write8(coreId: id, address: address, value: UInt8(value & 0xFF))
            case 1:  // SH
                _ = memoryBus.write16(coreId: id, address: address, value: UInt16(value & 0xFFFF))
            case 2:  // SW
                _ = memoryBus.write32(coreId: id, address: address, value: UInt32(value & 0xFFFFFFFF))
            case 3:  // SD
                _ = memoryBus.write64(coreId: id, address: address, value: value)
            default: break
            }
            
            if debug {
                print("[Core \(id)] STORE: addr=0x\(String(format: "%X", address)), val=\(value), size=\(memSize)")
            }
            
        } else if opcode == 0x27 {  // STORE-FP
            let fpValue = fpRegisters[Int(rs2)]
            
            if memSize == 2 {  // FSW
                let bits = Float(fpValue).bitPattern
                _ = memoryBus.write32(coreId: id, address: address, value: bits)
            } else if memSize == 3 {  // FSD
                let bits = fpValue.bitPattern
                _ = memoryBus.write64(coreId: id, address: address, value: bits)
            }
        }
        
        instructionsExecuted += 1
    }
    
    // MARK: - B-Type
    
    private func executeBType(funct3: UInt8, rs1: UInt8, rs2: UInt8, imm: Int16, pc: UInt64) {
        let a = registers[Int(rs1)]
        let b = registers[Int(rs2)]
        var taken = false
        
        // Predict branch outcome
        let predicted = branchPredictor.predict(pc: pc)
        
        switch funct3 {
        case 0x0: taken = (a == b)  // BEQ
        case 0x1: taken = (a != b)  // BNE
        case 0x4: taken = (Int64(bitPattern: a) < Int64(bitPattern: b))  // BLT
        case 0x5: taken = (Int64(bitPattern: a) >= Int64(bitPattern: b))  // BGE
        case 0x6: taken = (a < b)  // BLTU
        case 0x7: taken = (a >= b)  // BGEU
        default: break
        }
        
        // Update predictor with actual outcome
        branchPredictor.update(pc: pc, actualTaken: taken)
        
        // Track mispredictions
        if predicted != taken {
            branchMispredictions += 1
        }
        
        if debug {
            print("[Core \(id)] Branch: funct3=0x\(String(format: "%X", funct3)), a=\(a), b=\(b), taken=\(taken), predicted=\(predicted)")
        }
        
        if taken {
            self.pc = pc &+ UInt64(bitPattern: Int64(imm))
            branchesTaken += 1
        } else {
            branchesNotTaken += 1
        }
        
        instructionsExecuted += 1
    }
    
    // MARK: - U-Type
    
    private func executeUType(opcode: UInt8, rd: UInt8, imm: Int32, pc: UInt64) {
        var result: UInt64 = 0
        
        if opcode == 0x37 {  // LUI
            result = UInt64(bitPattern: Int64(imm))
        } else if opcode == 0x17 {  // AUIPC
            result = pc &+ UInt64(bitPattern: Int64(imm))
        }
        
        if rd != 0 {
            registers[Int(rd)] = result
        }
        instructionsExecuted += 1
    }
    
    // MARK: - J-Type
    
    private func executeJType(rd: UInt8, imm: Int32, pc: UInt64) {
        if rd != 0 {
            registers[Int(rd)] = pc + 4  // 다음 명령어 주소 저장
        }
        self.pc = pc &+ UInt64(bitPattern: Int64(imm))
        instructionsExecuted += 1
    }
    
    // MARK: - Atomic
    
    private func executeAtomic(rd: UInt8, funct3: UInt8, rs1: UInt8, rs2: UInt8, funct7: UInt8) {
        let address = registers[Int(rs1)]
        let funct5 = funct7 >> 2
        let memSize = funct3 & 0x3
        let size = 1 << memSize
        
        switch funct5 {
        case 0x02:  // LR
            loadReservation = address
            if size == 4 {
                if let val = memoryBus.read32(coreId: id, address: address) {
                    registers[Int(rd)] = UInt64(bitPattern: Int64(Int32(bitPattern: val)))
                }
            } else {
                if let val = memoryBus.read64(coreId: id, address: address) {
                    registers[Int(rd)] = val
                }
            }
            
        case 0x03:  // SC
            if loadReservation == address {
                let value = registers[Int(rs2)]
                let success = (size == 4) ?
                    memoryBus.write32(coreId: id, address: address, value: UInt32(value & 0xFFFFFFFF)) :
                    memoryBus.write64(coreId: id, address: address, value: value)
                registers[Int(rd)] = success ? 0 : 1
            } else {
                registers[Int(rd)] = 1
            }
            loadReservation = nil
            
        default:
            // 기타 AMO 연산 (생략)
            break
        }
        
        instructionsExecuted += 1
    }
    
    // MARK: - Step Interface
    
    /// Run the core in a host thread, notifying the scheduler of events
    /// Run the core in a host thread, notifying the scheduler of events
    #if os(macOS)
    @available(macOS 10.15.4, *)
    #endif
    func runLoop(scheduler: Scheduler, quantum: Int = 4) {
        while !halted {
            let res = step(quantum: quantum)
            scheduler.notify(core: self, result: res)
            if res == .blocked {
                // Park briefly to avoid busy spin
                Thread.sleep(forTimeInterval: 0.0001)
            }
            if res == .exit { break }
        }
    }
    
    func step(quantum: Int = 1) -> StepResult {
        if halted { return .exit }
        var executed = 0
        pendingStepResult = nil
        
        while executed < quantum {
            memoryBus.batch {
                tick()
                memoryBus.tick()
            }
            
            if let ev = pendingStepResult {
                pendingStepResult = nil
                switch ev {
                case .continue:
                    executed += 1
                    continue
                case .yield:
                    return .yield
                case .blocked:
                    return .blocked
                case .exit:
                    return .exit
                }
            }
            
            if halted { return .exit }
            executed += 1
        }
        
        return .continue
    }
    
    // MARK: - Status
    
    func printStatus() {
        print("Core \(id) Status:")
        print("  PC: \(String(format: "0x%X", pc))")
        print("  Cycles: \(cyclesExecuted)")
        print("  Instructions: \(instructionsExecuted)")
        print("  CPI: \(cyclesExecuted > 0 ? Double(cyclesExecuted) / Double(max(instructionsExecuted, 1)) : 0)")
        print("  Branches: \(branchesTaken) taken, \(branchesNotTaken) not taken")
        
        let totalBranches = branchesTaken + branchesNotTaken
        if totalBranches > 0 {
            print("\n  Branch Predictor:")
            print("    Predictions: \(branchPredictor.predictions)")
            print("    Correct: \(branchPredictor.correct)")
            print("    Incorrect: \(branchPredictor.incorrect)")
            print("    Accuracy: \(String(format: "%.1f%%", branchPredictor.accuracy))")
            print("    Unique Branches: \(branchPredictor.uniqueBranches)")
        }
        
        print("  Halted: \(halted)")
        
        if let cache = l1Cache {
            print("")
            cache.printStats()
        }
    }
    
    // CSR Helper
    func getCSR(_ addr: Int) -> UInt64 {
        return state.csr[addr] ?? 0
    }
    
    func setCSR(_ addr: Int, value: UInt64) {
        state.csr[addr] = value
    }
    
    // MARK: - Interrupt Handling
    
    /// Trigger an interrupt (set bit in MIP)
    func runInterrupt(bit: Int, active: Bool) {
        var mip = getCSR(0x344) // MIP
        if active {
            mip |= (1 << UInt64(bit))
        } else {
            mip &= ~(1 << UInt64(bit))
        }
        setCSR(0x344, value: mip)
    }
    
    private func checkInterrupts() -> UInt64? {
        let mip = getCSR(0x344)
        let mie = getCSR(0x304)
        let mstatus = getCSR(0x300)
        
        // Check MIE bit (Global Interrupt Enable)
        if (mstatus & 0x8) == 0 {
            return nil
        }
        
        // Pending & Enabled
        let pending = mip & mie
        
        if pending != 0 {
            // Priority: External(11) > Software(3) > Timer(7)
            // For now, checks Timer(7)
            if (pending & (1 << 7)) != 0 {
                return 0x8000000000000007 // Interrupt bit set + code 7
            }
        }
        return nil
    }
    
    private func enterTrap(cause: UInt64, isInterrupt: Bool) {
        let pc = self.pc
        
        // 1. Save PC to MEPC
        setCSR(0x341, value: pc)
        
        // 2. Save MIE to MPIE
        var mstatus = getCSR(0x300)
        let mie = (mstatus & 0x8) != 0
        if mie {
            mstatus |= 0x80 // MPIE = 1
        } else {
            mstatus &= ~0x80 // MPIE = 0
        }
        
        // 3. Clear MIE (Disable Interrupts)
        mstatus &= ~0x8 // MIE = 0
        setCSR(0x300, value: mstatus)
        
        // 4. Set MCAUSE
        setCSR(0x342, value: cause)
        
        // 5. Jump to MTVEC
        let mtvec = getCSR(0x305)
        // Check mode (Direct vs Vectored)
        // Mode is last 2 bits. Assume Direct (0) for now or basic support.
        let base = mtvec & ~0x3
        self.pc = base
        
        if debug {
            print("[Core \(id)] Trap! Cause: 0x\(String(format: "%X", cause)), PC -> 0x\(String(format: "%X", self.pc))")
        }
    }
}
