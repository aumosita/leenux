import Foundation

/// 2-bit Saturating Counter Branch Predictor
/// 
/// 각 분기 명령어(PC)마다 2-bit 상태를 유지하여 taken/not-taken 예측
/// 한 번의 오예측으로는 예측 방향이 바뀌지 않아 안정적
class TwoBitBranchPredictor {
    /// 2-bit 상태 (Saturating Counter)
    enum State: UInt8 {
        case strongNotTaken = 0  // 00: Strong bias toward not-taken
        case weakNotTaken = 1    // 01: Weak bias toward not-taken
        case weakTaken = 2        // 10: Weak bias toward taken
        case strongTaken = 3      // 11: Strong bias toward taken
        
        /// 현재 상태에서 예측 결과
        var prediction: Bool {
            return self == .weakTaken || self == .strongTaken
        }
    }
    
    /// Branch History Table: PC → State
    private var table: [UInt64: State] = [:]
    
    /// Statistics
    private(set) var predictions: Int = 0
    private(set) var correct: Int = 0
    private(set) var incorrect: Int = 0
    
    /// Default state for unseen branches
    private let defaultState: State = .weakNotTaken
    
    init() {
        self.table.reserveCapacity(1024)
    }
    
    /// Predict whether branch at PC will be taken
    func predict(pc: UInt64) -> Bool {
        let state = table[pc, default: defaultState]
        predictions += 1
        return state.prediction
    }
    
    /// Update predictor with actual branch outcome
    func update(pc: UInt64, actualTaken: Bool) {
        let current = table[pc, default: defaultState]
        let newState = transition(from: current, taken: actualTaken)
        table[pc] = newState
        
        // Update statistics
        if current.prediction == actualTaken {
            correct += 1
        } else {
            incorrect += 1
        }
    }
    
    /// State transition based on actual outcome
    private func transition(from state: State, taken: Bool) -> State {
        if taken {
            // Increment toward Strong Taken
            switch state {
            case .strongNotTaken: return .weakNotTaken
            case .weakNotTaken: return .weakTaken
            case .weakTaken: return .strongTaken
            case .strongTaken: return .strongTaken
            }
        } else {
            // Decrement toward Strong Not-Taken
            switch state {
            case .strongNotTaken: return .strongNotTaken
            case .weakNotTaken: return .strongNotTaken
            case .weakTaken: return .weakNotTaken
            case .strongTaken: return .weakTaken
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Prediction accuracy (%)
    var accuracy: Double {
        let total = correct + incorrect
        return total > 0 ? Double(correct) / Double(total) * 100 : 0
    }
    
    /// Number of unique branches tracked
    var uniqueBranches: Int {
        return table.count
    }
    
    /// Reset statistics (keep learned patterns)
    func resetStats() {
        predictions = 0
        correct = 0
        incorrect = 0
    }
    
    /// Clear all learned patterns
    func clear() {
        table.removeAll(keepingCapacity: true)
        resetStats()
    }
}
