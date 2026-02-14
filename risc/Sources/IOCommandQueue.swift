import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// I/O Command Queue for Core-to-Core Communication
/// 
/// Core 0 (Main CPU) writes commands
/// Core 1 (I/O Processor) reads and executes commands
class IOCommandQueue {
    /// Command types for I/O operations
    enum Command {
        case writePixel(x: Int, y: Int, color: UInt32)
        case printChar(c: UInt8)
        case readKeyboard
        case flushFramebuffer
        case nop
    }
    
    private var queue: [Command] = []
    private var lock = pthread_mutex_t()
    private let capacity: Int
    
    // Statistics
    private(set) var enqueued: Int = 0
    private(set) var dequeued: Int = 0
    private(set) var dropped: Int = 0
    
    init(capacity: Int = 1024) {
        self.capacity = capacity
        pthread_mutex_init(&lock, nil)
        self.queue.reserveCapacity(capacity)
    }
    
    deinit {
        pthread_mutex_destroy(&lock)
    }
    
    /// Enqueue command (called by Core 0)
    func enqueue(_ command: Command) -> Bool {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        if queue.count >= capacity {
            dropped += 1
            return false
        }
        
        queue.append(command)
        enqueued += 1
        return true
    }
    
    /// Dequeue command (called by Core 1)
    func dequeue() -> Command? {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        if queue.isEmpty {
            return nil
        }
        
        dequeued += 1
        return queue.removeFirst()
    }
    
    /// Peek next command without removing
    func peek() -> Command? {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        return queue.first
    }
    
    /// Check if queue is empty
    var isEmpty: Bool {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        return queue.isEmpty
    }
    
    /// Current queue size
    var count: Int {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        return queue.count
    }
    
    /// Clear all commands
    func clear() {
        pthread_mutex_lock(&lock)
        defer { pthread_mutex_unlock(&lock) }
        
        queue.removeAll(keepingCapacity: true)
    }
    
    // MARK: - Statistics
    
    /// Queue utilization (%)
    var utilization: Double {
        return Double(count) / Double(capacity) * 100
    }
    
    /// Total commands processed
    var totalProcessed: Int {
        return dequeued
    }
    
    /// Drop rate (%)
    var dropRate: Double {
        let total = enqueued + dropped
        return total > 0 ? Double(dropped) / Double(total) * 100 : 0
    }
    
    func printStats() {
        print("\n=== I/O Command Queue Statistics ===")
        print("Enqueued: \(enqueued)")
        print("Dequeued: \(dequeued)")
        print("Dropped: \(dropped)")
        print("Drop Rate: \(String(format: "%.2f%%", dropRate))")
        print("Current Size: \(count) / \(capacity)")
        print("Utilization: \(String(format: "%.1f%%", utilization))")
    }
}
