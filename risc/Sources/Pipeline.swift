import Foundation

// MARK: - Pipeline Registers (F/D Extension Integrated)

/// IF/ID 파이프라인 레지스터
struct IFIDRegister {
    var pc: UInt64
    var instruction: UInt32
    var valid: Bool
    
    init() {
        self.pc = 0
        self.instruction = 0
        self.valid = false
    }
}

/// ID/EX 파이프라인 레지스터
struct IDEXRegister {
    var pc: UInt64
    
    // Integer Operands
    var rs1Value: UInt64
    var rs2Value: UInt64
    var immediate: Int64
    
    // FP Operands
    var rs1FpValue: Double
    var rs2FpValue: Double
    var rs3FpValue: Double // Reserved for FMA
    
    // Register Specifiers
    var rd: UInt8
    var rs1: UInt8
    var rs2: UInt8
    
    // Control Signals
    var aluOp: ALUOp
    var aluSrc: Bool        // true: immediate, false: rs2
    var memRead: Bool
    var memWrite: Bool
    var memToReg: Bool      // true: memory, false: ALU result
    var regWrite: Bool
    var branch: Bool
    var jump: Bool
    
    // FP Control Signals
    var isFpOp: Bool        // FP ALU Operation
    var isFpRd: Bool        // Write back to FP register
    var memIsFp: Bool       // Memory access is FP
    var rm: UInt8           // Rounding Mode
    
    // Memory Info
    var memSize: UInt8
    var memSigned: Bool
    
    var valid: Bool
    
    // Atomic Info
    var isAtomic: Bool
    var atomicOp: AtomicOp
    var ordering: (aq: Bool, rl: Bool)
    
    // EBREAK / ECALL Support
    var isEbreak: Bool
    var isEcall: Bool
    
    init() {
        self.pc = 0
        self.rs1Value = 0
        self.rs2Value = 0
        self.immediate = 0
        self.rs1FpValue = 0.0
        self.rs2FpValue = 0.0
        self.rs3FpValue = 0.0
        self.rd = 0
        self.rs1 = 0
        self.rs2 = 0
        self.aluOp = .add
        self.aluSrc = false
        self.memRead = false
        self.memWrite = false
        self.memToReg = false
        self.regWrite = false
        self.branch = false
        self.jump = false
        self.isFpOp = false
        self.isFpRd = false
        self.memIsFp = false
        self.rm = 0
        self.memSize = 3
        self.memSigned = false
        self.valid = false
        self.isAtomic = false
        self.atomicOp = .none
        self.ordering = (false, false)
        self.isEbreak = false
        self.isEcall = false
    }
}

/// EX/MEM 파이프라인 레지스터
struct EXMEMRegister {
    var aluResult: UInt64
    var aluFpResult: Double
    
    var branchTarget: UInt64
    var branchTaken: Bool
    
    var writeData: UInt64
    var writeFpData: Double
    
    var rd: UInt8
    
    var memRead: Bool
    var memWrite: Bool
    var memToReg: Bool
    var regWrite: Bool
    var jump: Bool
    
    // FP Info
    var isFpRd: Bool
    var memIsFp: Bool // True if storing FP data or loading to FP reg
    
    var memSize: UInt8
    var memSigned: Bool
    
    var valid: Bool

    // Atomic Info
    var isAtomic: Bool
    var atomicOp: AtomicOp
    var ordering: (aq: Bool, rl: Bool)
    
    // EBREAK / ECALL Support
    var isEbreak: Bool
    var isEcall: Bool
    
    init() {
        self.aluResult = 0
        self.aluFpResult = 0.0
        self.branchTarget = 0
        self.branchTaken = false
        self.writeData = 0
        self.writeFpData = 0.0
        self.rd = 0
        self.memRead = false
        self.memWrite = false
        self.memToReg = false
        self.regWrite = false
        self.jump = false
        self.isFpRd = false
        self.memIsFp = false
        self.memSize = 3
        self.memSigned = false
        self.valid = false
        self.isAtomic = false
        self.atomicOp = .none
        self.ordering = (false, false)
        self.isEbreak = false
        self.isEcall = false
    }
}

/// MEM/WB 파이프라인 레지스터
struct MEMWBRegister {
    var aluResult: UInt64
    var aluFpResult: Double
    
    var memData: UInt64
    var memFpData: Double
    
    var rd: UInt8
    
    var memToReg: Bool
    var regWrite: Bool
    
    var isFpRd: Bool 
    
    var valid: Bool
    
    // EBREAK / ECALL Support
    var isEbreak: Bool
    var isEcall: Bool
    
    init() {
        self.aluResult = 0
        self.aluFpResult = 0.0
        self.memData = 0
        self.memFpData = 0.0
        self.rd = 0
        self.memToReg = false
        self.regWrite = false
        self.isFpRd = false 
        self.valid = false
        self.isEbreak = false
        self.isEcall = false
    }
}

/// 파이프라인 레지스터 세트
struct PipelineRegisters {
    var ifId: IFIDRegister
    var idEx: IDEXRegister
    var exMem: EXMEMRegister
    var memWb: MEMWBRegister
    
    init() {
        self.ifId = IFIDRegister()
        self.idEx = IDEXRegister()
        self.exMem = EXMEMRegister()
        self.memWb = MEMWBRegister()
    }
    
    mutating func flush() {
        ifId.valid = false
        idEx.valid = false
        exMem.valid = false
        // Clear any exceptional flags in case of flush
        idEx.isEbreak = false
        idEx.isEcall = false
        exMem.isEbreak = false
        exMem.isEcall = false
        memWb.isEbreak = false
        memWb.isEcall = false
    }
    
    mutating func stall() {
        idEx.valid = false
        idEx.regWrite = false
        idEx.memWrite = false
        idEx.memRead = false
        idEx.isEbreak = false
        idEx.isEcall = false
    }
}

// MARK: - ALU Operations

enum ALUOp {
    // Integer
    case add, sub, and, or, xor, sll, srl, sra
    case slt, sltu
    
    // M Extension
    case mul, mulh, mulhsu, mulhu
    case div, divu, rem, remu
    
    // Branch
    case beq, bne, blt, bge, bltu, bgeu
    
    // FP Extension
    case fadd_s, fsub_s, fmul_s, fdiv_s, fsqrt_s
    case fmin_s, fmax_s, feq_s, flt_s, fle_s
    case fsgnj_s, fsgnjn_s, fsgnjx_s
    
    case fadd_d, fsub_d, fmul_d, fdiv_d, fsqrt_d
    case fmin_d, fmax_d, feq_d, flt_d, fle_d
    case fsgnj_d, fsgnjn_d, fsgnjx_d
    
    case fcvt_w_s, fcvt_wu_s, fcvt_s_w, fcvt_s_wu
    case fcvt_l_s, fcvt_lu_s, fcvt_s_l, fcvt_s_lu
    case fcvt_w_d, fcvt_wu_d, fcvt_d_w, fcvt_d_wu
    case fcvt_l_d, fcvt_lu_d, fcvt_d_l, fcvt_d_lu
    case fcvt_s_d, fcvt_d_s
    
    case fmv_x_w, fmv_w_x, fmv_x_d, fmv_d_x
    
    case nop
}

// MARK: - Atomic Operations

enum AtomicOp {
    case lr, sc
    case amoswap, amoadd, amoxor, amoand, amoor
    case amomin, amomax, amominu, amomaxu
    case none
}

// MARK: - Forwarding Unit

/// 포워딩 소스
enum ForwardSource {
    case none       // 포워딩 없음
    case exMem      // EX/MEM 레지스터에서
    case memWb      // MEM/WB 레지스터에서
}

/// 포워딩 유닛 (Data Hazard 해결)
struct ForwardingUnit {
    /// EX 단계의 rs1에 대한 포워딩 결정
    static func forwardA(idExRs1: UInt8, exMemRd: UInt8, exMemRegWrite: Bool,
                         memWbRd: UInt8, memWbRegWrite: Bool) -> ForwardSource {
        // EX/MEM에서 포워딩
        if exMemRegWrite && exMemRd != 0 && exMemRd == idExRs1 {
            return .exMem
        }
        // MEM/WB에서 포워딩
        if memWbRegWrite && memWbRd != 0 && memWbRd == idExRs1 {
            return .memWb
        }
        return .none
    }
    
    /// EX 단계의 rs2에 대한 포워딩 결정
    static func forwardB(idExRs2: UInt8, exMemRd: UInt8, exMemRegWrite: Bool,
                         memWbRd: UInt8, memWbRegWrite: Bool) -> ForwardSource {
        // EX/MEM에서 포워딩
        if exMemRegWrite && exMemRd != 0 && exMemRd == idExRs2 {
            return .exMem
        }
        // MEM/WB에서 포워딩
        if memWbRegWrite && memWbRd != 0 && memWbRd == idExRs2 {
            return .memWb
        }
        return .none
    }
}

// MARK: - Hazard Detection Unit

/// Hazard Detection 유닛 (Load-Use Hazard 감지)
struct HazardDetectionUnit {
    /// Load-Use hazard 감지
    /// ID 단계의 명령어가 EX 단계의 load 결과를 사용하려는 경우
    static func detectLoadUseHazard(idExMemRead: Bool, idExRd: UInt8,
                                    ifIdRs1: UInt8, ifIdRs2: UInt8) -> Bool {
        if idExMemRead {
            if idExRd == ifIdRs1 || idExRd == ifIdRs2 {
                return true  // Stall 필요
            }
        }
        return false
    }
}

// MARK: - Branch Predictor

/// 1-bit Dynamic Branch Predictor
///
/// 각 분기 명령어의 PC를 키로 하여 마지막 분기 결과를 저장합니다.
/// 다음 분기 시 저장된 결과를 예측값으로 사용합니다.
///
/// 예측 정확도: 일반적으로 70-85%
class BranchPredictor {
    /// 분기 예측 테이블 (PC → 마지막 분기 결과)
    /// true = taken, false = not taken
    private var predictionTable: [UInt64: Bool] = [:]
    
    /// 통계
    var totalPredictions: Int = 0
    var correctPredictions: Int = 0
    var incorrectPredictions: Int = 0
    
    /// 분기 예측
    /// - Parameter pc: 분기 명령어의 PC
    /// - Returns: 예측 결과 (true = taken, false = not taken)
    func predict(pc: UInt64) -> Bool {
        totalPredictions += 1
        
        // 테이블에 해당 PC가 있으면 저장된 값 반환
        // 없으면 기본값 false (not taken) 반환
        return predictionTable[pc] ?? false
    }
    
    /// 분기 결과로 예측 테이블 업데이트
    /// - Parameters:
    ///   - pc: 분기 명령어의 PC
    ///   - actualTaken: 실제 분기 결과
    ///   - predicted: 예측했던 값
    func update(pc: UInt64, actualTaken: Bool, predicted: Bool) {
        // 예측 테이블 업데이트 (1-bit: 마지막 결과를 그대로 저장)
        predictionTable[pc] = actualTaken
        
        // 통계 업데이트
        if actualTaken == predicted {
            correctPredictions += 1
        } else {
            incorrectPredictions += 1
        }
    }
    
    /// 예측 정확도 계산
    var accuracy: Double {
        guard totalPredictions > 0 else { return 0.0 }
        return Double(correctPredictions) / Double(totalPredictions) * 100.0
    }
    
    /// 통계 리셋
    func resetStats() {
        totalPredictions = 0
        correctPredictions = 0
        incorrectPredictions = 0
    }
    
    /// 예측 테이블 클리어
    func clearTable() {
        predictionTable.removeAll()
        resetStats()
    }
    
    /// 통계 출력
    func printStats() {
        print("Branch Predictor Statistics:")
        print("  Total predictions: \(totalPredictions)")
        print("  Correct: \(correctPredictions)")
        print("  Incorrect: \(incorrectPredictions)")
        print("  Accuracy: \(String(format: "%.2f", accuracy))%")
        print("  Table size: \(predictionTable.count) entries")
    }
}
