import Foundation

/// 간단한 Scheduler 스켈레톤
/// - 목표: Emulator 역할 축소 후 스케줄링/호스트 스레드 매핑의 진입점 제공
#if os(macOS)
@available(macOS 10.15.4, *)
#endif
class Scheduler {
    // Dynamic list of cores managed by scheduler
    var cores: [CoreSimple]
    let quantum: Int
    var running = false
    var runningMultiThreaded = false
    private let syncQueue = DispatchQueue(label: "scheduler.sync")
    weak var kernel: KernelProtocol?

    init(cores: [CoreSimple], kernel: KernelProtocol? = nil, quantum: Int = 4) {
        self.cores = cores
        self.quantum = quantum
        self.kernel = kernel
    }

    /// 단순한 싱글스레드 스케줄러 (초기화/테스트용)
    func startSingleThreaded(maxRounds: Int = 10000) {
        running = true
        var rounds = 0

        while running && rounds < maxRounds {
            var allHalted = true
            for core in cores {
                if core.halted { continue }
                allHalted = false

                let result = core.step(quantum: quantum)
                switch result {
                case .continue:
                    break
                case .yield:
                    print("[Scheduler] Core \(core.id) yielded (syscall/yield)")
                case .blocked:
                    // 메모리 대기 등, 스케줄러는 다음 코어로 넘어감
                    break
                case .exit:
                    print("[Scheduler] Core \(core.id) exited")
                }
            }

            if allHalted {
                running = false
            }
            rounds += 1
        }
    }

    /// Notify scheduler of a core event (called from Core.runLoop or step)
    func notify(core: CoreSimple, result: StepResult) {
        switch result {
        case .continue:
            break
        case .yield:
            // Route to kernel if available
            if let k = kernel {
                let kr = k.handleSyscall(core: core)
                switch kr {
                case .continue:
                    break
                case .yield:
                    print("[Scheduler] Core \(core.id) yielded (kernel requested further action)")
                case .blocked:
                    print("[Scheduler] Core \(core.id) blocked by kernel")
                case .exit:
                    core.halted = true
                }
            } else {
                print("[Scheduler] Core \(core.id) yielded (syscall/yield)")
            }
        case .blocked:
            // Core blocked on memory; scheduler may choose other cores
            break
        case .exit:
            print("[Scheduler] Core \(core.id) exited")
        }
    }

    /// Start each core on a separate host thread (1:1 mapping)
    func startMultiThreaded(quantum: Int = 4) {
        running = true
        runningMultiThreaded = true
        syncQueue.sync {
            for core in cores {
                startHostThread(for: core, quantum: quantum)
            }
        }
    }

    private func startHostThread(for core: CoreSimple, quantum: Int) {
        core.debug = false
        Thread.detachNewThread {
            while self.running && !core.halted {
                let res = core.step(quantum: quantum)
                self.notify(core: core, result: res)
                if res == .blocked {
                    Thread.sleep(forTimeInterval: 0.0001)
                }
                if res == .exit { break }
            }
        }
    }

    /// Add a core dynamically (spawned by kernel)
    func add(core: CoreSimple) {
        syncQueue.sync {
            cores.append(core)
            if runningMultiThreaded {
                // start a host thread for the new core
                startHostThread(for: core, quantum: quantum)
            }
        }
    }

    func shutdown() {
        running = false
    }
}
