# 크로스 플랫폼 호환 최적화 전략

## ⚠️ 문제점 분석

### 현재 구현의 플랫폼 종속성

```swift
// ❌ Apple 플랫폼 종속
import Foundation
let lock = NSLock()  // Foundation 전용

// ❌ Swift 전용
UnsafeMutablePointer<UInt32>
SIMD8<UInt32>

// ❌ macOS 전용
#if os(macOS)
OSMemoryBarrier()
#endif
```

---

## ✅ 크로스 플랫폼 해결책

### 1. POSIX 표준 사용 (권장)

**pthread_mutex (모든 UNIX 계열)**:
```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported platform")
#endif

class CrossPlatformLock {
    private var mutex = pthread_mutex_t()
    
    init() {
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func lock() {
        pthread_mutex_lock(&mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}
```

### 2. 플랫폼 추상화 레이어

```swift
// PlatformAbstraction.swift
#if os(macOS) || os(iOS)
import Foundation
typealias PlatformLock = NSLock
#elseif os(Linux) || os(FreeBSD)
class PlatformLock {
    private var mutex = pthread_mutex_t()
    
    init() {
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func lock() {
        pthread_mutex_lock(&mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}
#elseif os(Windows)
// Windows critical section
import WinSDK
class PlatformLock {
    private var cs = CRITICAL_SECTION()
    
    init() {
        InitializeCriticalSection(&cs)
    }
    
    deinit {
        DeleteCriticalSection(&cs)
    }
    
    func lock() {
        EnterCriticalSection(&cs)
    }
    
    func unlock() {
        LeaveCriticalSection(&cs)
    }
}
#endif

// 사용
class FramebufferDevice {
    private let lock = PlatformLock()  // 플랫폼 무관!
}
```

### 3. 조건부 컴파일 최소화

**알고리즘 중심 설계**:
```swift
// ✅ 플랫폼 독립적 (알고리즘만)
class DecodedInstructionCache {
    private var cache: [UInt32: Instruction] = [:]
    
    func decode(_ raw: UInt32) -> Instruction {
        if let cached = cache[raw] {
            return cached  // 순수 Swift (모든 플랫폼)
        }
        let decoded = Instruction.decode(raw: raw)
        cache[raw] = decoded
        return decoded
    }
}

// ✅ 배치 실행 (플랫폼 무관)
func executeBatch(count: Int) {
    for _ in 0..<count {
        let instr = fetch()
        execute(instr)
    }
}
```

### 4. 표준 API 사용

**메모리 관리**:
```swift
// ❌ Swift 특화
UnsafeMutablePointer<UInt32>

// ✅ 표준 Swift (모든 플랫폼)
var pixels: [UInt32]  // Array는 표준

// 또는 수동 메모리 관리 (C 호환)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

let ptr = malloc(size).assumingMemoryBound(to: UInt32.self)
defer { free(ptr) }
```

---

## 🎯 플랫폼 독립적 최적화 전략

### Tier 1: 순수 알고리즘 (100% 호환)

```swift
// ✅ 모든 플랫폼
1. Decode Caching (딕셔너리)
2. Batch Execution (루프 최적화)
3. Early Exit (조건문)
4. Lazy Evaluation (지연 계산)
```

### Tier 2: 표준 라이브러리 (95% 호환)

```swift
// ✅ Swift 표준 (Linux, macOS, Windows)
1. Array operations
2. Dictionary
3. Standard loops
4. Value types
```

### Tier 3: POSIX 표준 (90% 호환)

```swift
// ✅ UNIX 계열 (Linux, macOS, BSD)
1. pthread_mutex
2. pthread_cond
3. POSIX threads
4. Standard C library
```

### Tier 4: 조건부 컴파일 (모든 플랫폼)

```swift
// ✅ 모든 플랫폼 (각각 구현)
#if os(macOS)
    // macOS specific
#elseif os(Linux)
    // Linux specific
#elseif os(Windows)
    // Windows specific
#endif
```

---

## 🔧 실용적 구현

### 크로스 플랫폼 Store Buffer

```swift
// CrossPlatformStoreBuffer.swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

class StoreBuffer {
    struct Entry {
        let address: UInt64
        let value: UInt64
        let size: Int
    }
    
    // ✅ 표준 Swift 타입 (모든 플랫폼)
    private var buffer: [Entry] = []
    private let capacity: Int
    
    // ✅ POSIX mutex (거의 모든 플랫폼)
    private var mutex = pthread_mutex_t()
    
    init(capacity: Int = 32) {
        self.capacity = capacity
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func add(address: UInt64, value: UInt64, size: Int) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        if buffer.count >= capacity {
            flushInternal()
        }
        
        buffer.append(Entry(address: address, value: value, size: size))
    }
    
    // ✅ 순수 알고리즘 (플랫폼 무관)
    private func flushInternal() {
        buffer.removeAll(keepingCapacity: true)
    }
}
```

### 크로스 플랫폼 Double Buffering

```swift
class DoubleBufferedFramebuffer {
    // ✅ 표준 Array (모든 플랫폼)
    private var frontBuffer: [UInt32]
    private var backBuffer: [UInt32]
    
    // ✅ POSIX mutex
    private var mutex = pthread_mutex_t()
    
    init(width: Int, height: Int) {
        let count = width * height
        self.frontBuffer = Array(repeating: 0, count: count)
        self.backBuffer = Array(repeating: 0, count: count)
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func swap() {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        // ✅ 표준 Swift swap (모든 플랫폼)
        (frontBuffer, backBuffer) = (backBuffer, frontBuffer)
    }
}
```

---

## 📊 플랫폼 호환성 매트릭스

| 최적화 | macOS | Linux | Windows | BSD | 호환성 |
|--------|-------|-------|---------|-----|--------|
| **Decode Cache** | ✅ | ✅ | ✅ | ✅ | 100% |
| **Batch Exec** | ✅ | ✅ | ✅ | ✅ | 100% |
| **pthread_mutex** | ✅ | ✅ | ⚠️ | ✅ | 90% |
| **Array Buffer** | ✅ | ✅ | ✅ | ✅ | 100% |
| **Store Buffer** | ✅ | ✅ | ✅ | ✅ | 100% |
| **NSLock** | ✅ | ❌ | ❌ | ❌ | 25% |
| **UnsafePointer** | ✅ | ✅ | ✅ | ✅ | 100% |

**권장**:
- pthread_mutex: POSIX 표준 (UNIX 계열 90%+)
- Windows: WinAPI critical section 조건부 사용
- 순수 알고리즘: 최우선 (100% 호환)

---

## 🎯 개선 우선순위

### Phase 1: NSLock → pthread_mutex
```swift
// Before (Apple only)
import Foundation
let lock = NSLock()

// After (cross-platform)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
var mutex = pthread_mutex_t()
pthread_mutex_init(&mutex, nil)
```

### Phase 2: 플랫폼 추상화 레이어
```swift
// PlatformLock.swift
class PlatformLock {
    #if os(macOS) || os(Linux)
    private var mutex = pthread_mutex_t()
    #elseif os(Windows)
    private var cs = CRITICAL_SECTION()
    #endif
    
    // 통일된 인터페이스
    func lock() { ... }
    func unlock() { ... }
}
```

### Phase 3: 순수 알고리즘 우선
```swift
// 최우선: 플랫폼 무관 최적화
1. Decode Caching
2. Batch Execution
3. Early Exit
4. Instruction Buffering

// 그 다음: 표준 API
5. Array operations
6. Dictionary
7. Standard types
```

---

## 💡 권장 사항

### DO (✅)
```
1. 순수 알고리즘 최적화 우선
2. Swift 표준 라이브러리 사용
3. POSIX 표준 API (pthread)
4. 조건부 컴파일로 플랫폼별 대응
5. 추상화 레이어 제공
```

### DON'T (❌)
```
1. Foundation 전용 API (NSLock, NSObject)
2. macOS 전용 기능
3. Swift Package Manager 플랫폼 제한
4. 하드코딩된 플랫폼 가정
5. 플랫폼별 최적화에 의존
```

---

## 📚 테스트 매트릭스

### 필수 테스트 플랫폼
```
1. macOS (x86_64, ARM64)
2. Linux (Ubuntu, Debian, Fedora)
3. Windows (x64) - Swift on Windows
4. FreeBSD (optional)
```

### CI/CD 통합
```yaml
# .github/workflows/test.yml
jobs:
  test-cross-platform:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

---

## 🎯 결론

### 올바른 접근
```
플랫폼 독립적 최적화:
  ✅ 알고리즘 개선 (decode cache, batch exec)
  ✅ 데이터 구조 최적화 (buffering)
  ✅ 표준 API 사용
  ✅ 조건부 컴파일 (필요시만)

플랫폼 종속적 최적화:
  ❌ NSLock, Foundation 의존
  ❌ macOS 전용 API
  ❌ 특정 하드웨어 가정
```

### 우선순위
```
1순위: 순수 알고리즘 (100% 호환)
2순위: Swift 표준 (95% 호환)
3순위: POSIX 표준 (90% 호환)
4순위: 플랫폼별 구현 (조건부)
```

---

*작성일: 2026-02-14*
*원칙: Write once, run anywhere*
