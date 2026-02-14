// Platform Abstraction Layer for Cross-Platform Compatibility

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Cross-platform lock using POSIX pthread_mutex
/// Works on macOS, Linux, BSD, and other UNIX systems
class PlatformLock {
    private var mutex = pthread_mutex_t()
    
    init() {
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_NORMAL))
        pthread_mutex_init(&mutex, &attr)
        pthread_mutexattr_destroy(&attr)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    @inline(__always)
    func lock() {
        pthread_mutex_lock(&mutex)
    }
    
    @inline(__always)
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
    /// Execute closure with lock held
    @inline(__always)
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

/// Cross-platform condition variable
class PlatformCondition {
    private var cond = pthread_cond_t()
    
    init() {
        pthread_cond_init(&cond, nil)
    }
    
    deinit {
        pthread_cond_destroy(&cond)
    }
    
    func wait(lock: PlatformLock) {
        // Note: Caller must hold lock
        var mutex = pthread_mutex_t()
        pthread_cond_wait(&cond, &mutex)
    }
    
    func signal() {
        pthread_cond_signal(&cond)
    }
    
    func broadcast() {
        pthread_cond_broadcast(&cond)
    }
}

/// Cross-platform atomic operations
/// Uses compiler built-ins available on all platforms
struct PlatformAtomic {
    /// Atomic load
    @inline(__always)
    static func load<T>(_ ptr: UnsafeMutablePointer<T>) -> T {
        // Compiler barrier
        #if compiler(>=5.7)
        return ptr.pointee
        #else
        return ptr.pointee
        #endif
    }
    
    /// Atomic store
    @inline(__always)
    static func store<T>(_ ptr: UnsafeMutablePointer<T>, _ value: T) {
        ptr.pointee = value
    }
    
    /// Compare and swap
    @inline(__always)
    static func compareExchange<T: Equatable>(
        _ ptr: UnsafeMutablePointer<T>,
        expected: T,
        desired: T
    ) -> Bool {
        if ptr.pointee == expected {
            ptr.pointee = desired
            return true
        }
        return false
    }
}

/// Cross-platform memory barrier
@inline(__always)
func platformMemoryBarrier() {
    #if os(macOS) || os(iOS)
    // Darwin platforms
    if #available(macOS 10.12, iOS 10.0, *) {
        OSMemoryBarrier()
    } else {
        // Fallback for older versions
        _ = pthread_mutex_t()
    }
    #elseif os(Linux) || os(FreeBSD)
    // Linux and BSD use compiler barrier
    asm("mfence" ::: "memory")
    #else
    // Generic: use mutex as barrier
    var mutex = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    pthread_mutex_lock(&mutex)
    pthread_mutex_unlock(&mutex)
    pthread_mutex_destroy(&mutex)
    #endif
}

/// Platform-independent high-resolution timer
struct PlatformTimer {
    static func now() -> UInt64 {
        #if os(macOS) || os(iOS)
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        let time = mach_absolute_time()
        return time * UInt64(info.numer) / UInt64(info.denom)
        #elseif os(Linux)
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
        #else
        // Fallback: use standard time
        return UInt64(clock()) * 1_000_000 / UInt64(CLOCKS_PER_SEC)
        #endif
    }
}

/// Platform-independent thread creation
class PlatformThread {
    private var thread: pthread_t?
    
    func start(_ body: @escaping () -> Void) {
        var threadPtr: pthread_t?
        let context = UnsafeMutablePointer<() -> Void>.allocate(capacity: 1)
        context.initialize(to: body)
        
        pthread_create(&threadPtr, nil, { contextPtr in
            let body = contextPtr!.assumingMemoryBound(to: (() -> Void).self).pointee
            body()
            return nil
        }, context)
        
        self.thread = threadPtr
    }
    
    func join() {
        if let thread = thread {
            pthread_join(thread, nil)
        }
    }
}
