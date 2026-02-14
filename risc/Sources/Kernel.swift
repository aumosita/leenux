import Foundation

/// Kernel minimal interface for syscall/spawn/yield/sleep
protocol KernelProtocol: AnyObject {
    func handleSyscall(core: CoreSimple) -> StepResult
    func spawn(entryPC: UInt64) -> Int
    func yield(core: CoreSimple)
    func sleep(core: CoreSimple, ms: UInt64)
}

/// Simple Kernel implementation (naive, synchronized)
#if os(macOS)
@available(macOS 10.15.4, *)
#endif
final class Kernel: KernelProtocol {
    unowned let system: MultiCoreSystem
    private let syncQueue = DispatchQueue(label: "kernel.sync")

    init(system: MultiCoreSystem) {
        self.system = system
    }

    /// Handle ECALL based on register convention:
    /// - a7 (x17): syscall number
    /// - a0..a5 (x10..x15): args
    func handleSyscall(core: CoreSimple) -> StepResult {
        // Read syscall number
        let num = Int(core.registers[17])
        switch num {
        case 0: // exit(n)
            let code = core.registers[10]
            syncQueue.sync {
                core.halted = true
                print("[Kernel] Core \(core.id) exit(\(code))")
            }
            return .exit

        case 1: // yield
            // Request scheduler intervention
            syncQueue.sync {
                print("[Kernel] Core \(core.id) yield")
            }
            return .yield

        case 2: // spawn(entryPC)
            let entry = core.registers[10]
            let newId = spawn(entryPC: entry)
            // return new core id in a0
            core.registers[10] = UInt64(newId)
            print("[Kernel] Core \(core.id) spawned core \(newId) at 0x\(String(format: "%X", entry))")
            return .continue

        case 3: // sleep(ms)
            let ms = core.registers[10]
            syncQueue.sync {
                print("[Kernel] Core \(core.id) sleeping for \(ms) ms")
            }
            // Block the current host thread to simulate sleep
            Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
            return .continue

        default:
            syncQueue.sync {
                print("[Kernel] Core \(core.id) unknown syscall \(num)")
            }
            return .continue
        }
    }

    func spawn(entryPC: UInt64) -> Int {
        return syncQueue.sync {
            let newId = system.cores.count
            let core = CoreSimple(id: newId, memoryBus: system.memoryBus, startPC: entryPC, enableCache: system.cores.first?.enableCache ?? true)
            // Add to system and scheduler
            system.cores.append(core)
            system.scheduler?.add(core: core)
            return newId
        }
    }

    func yield(core: CoreSimple) {
        _ = handleSyscall(core: core)
    }

    func sleep(core: CoreSimple, ms: UInt64) {
        // Blocking sleep; call Thread.sleep
        Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
    }
}
