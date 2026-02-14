# 병렬 실행 아키텍처

## 🎯 목표: 호스트 CPU 완전 활용

에뮬레이터의 각 가상 코어가 **호스트 CPU의 물리 코어를 독립적으로 사용**하여 진짜 병렬 실행을 달성합니다.

---

## 🏗️ 아키텍처

### 현재 구조
```
Host System (macOS - 8 physical cores)
├── Thread 1: Core 0 (RISC-V)
├── Thread 2: Core 1 (RISC-V)
├── Thread 3: Core 2 (RISC-V)
├── Thread 4: Core 3 (RISC-V)
├── Thread 5: Core 4 (RISC-V)
├── Thread 6: Core 5 (RISC-V)
├── Thread 7: Core 6 (RISC-V)
└── Thread 8: Core 7 (RISC-V)

모두 Shared Memory 공유 (Thread-Safe)
```

### 실행 모드 비교

#### ❌ 순차 실행 모드 (현재 기본)
```swift
// MultiCoreSystem.runMultiCore()
for core in cores {
    if !core.halted {
        core.tick()  // 순차적으로 실행
    }
}
```

**문제점:**
- 한 번에 1개 코어만 실행
- 호스트 CPU 1개만 사용
- 나머지 7개 코어 놀음

#### ✅ 병렬 실행 모드 (Scheduler 사용)
```swift
// Scheduler.startMultiThreaded()
for core in cores {
    Thread.detachNewThread {
        while !core.halted {
            core.step(quantum: 4)  // 독립 실행
        }
    }
}
```

**장점:**
- 8개 코어 동시 실행
- 호스트 CPU 8개 모두 사용
- **진짜 병렬성** 달성

---

## 🔒 Thread-Safety 요구사항

병렬 실행을 위해 모든 공유 리소스가 thread-safe해야 합니다:

### 1. SharedMemory ✅
```swift
class SharedMemory {
    private let lock = NSRecursiveLock()
    
    func load64(address: UInt64) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        // ...
    }
}
```
- **상태**: 이미 구현됨
- **방식**: NSRecursiveLock

### 2. MemoryBus ✅
```swift
class MemoryBus {
    // Round-robin arbitration
    // Conflict detection
}
```
- **상태**: Thread-safe
- **방식**: Atomic operations + Lock

### 3. MMIO Devices 🔨
```swift
class UARTDevice: MMIODevice {
    private let bufferLock = NSLock()
    
    func write8(...) -> Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        // ...
    }
}
```
- **상태**: 지금 구현 중
- **필요**: UART, Timer, Framebuffer, Keyboard 모두 thread-safe

### 4. Cache (Per-Core) ✅
```swift
class Cache {
    // 각 코어마다 독립적인 L1 캐시
    // 공유 안 함 → Thread-safe 불필요
}
```
- **상태**: 이미 안전
- **이유**: 코어별 독립

---

## 📊 성능 비교

### 순차 실행
```
4개 코어, 각 100 사이클 실행

Host CPU 사용: 1개
소요 시간: 400 사이클
실제 병렬성: 0%
```

### 병렬 실행
```
4개 코어, 각 100 사이클 실행

Host CPU 사용: 4개
소요 시간: 100 사이클 (+ 약간의 동기화 오버헤드)
실제 병렬성: ~95%
속도 향상: ~4배
```

---

## 🚀 사용 방법

### Option 1: MultiCoreSystem에서 직접
```swift
// 현재 (순차 실행)
let system = MultiCoreSystem(numCores: 4)
system.loadProgram(at: 0x1000, data: program)
system.runMultiCore(maxCycles: 10000)  // ❌ 순차

// 변경 (병렬 실행)
let system = MultiCoreSystem(numCores: 4)
system.loadProgram(at: 0x1000, data: program)
system.runMultiCoreParallel(maxCycles: 10000)  // ✅ 병렬
```

### Option 2: Scheduler 사용
```swift
let system = MultiCoreSystem(numCores: 4)
system.loadProgram(at: 0x1000, data: program)

// Scheduler로 병렬 실행
system.scheduler?.startMultiThreaded(quantum: 4)

// 실행 대기
sleep(1)  // 또는 적절한 종료 조건

// 종료
system.scheduler?.shutdown()
```

---

## 🎯 구현 계획

### Phase 1: MMIO Thread-Safety ✅
- [x] Timer → 사이클 기반 + Lock
- [x] UART → Lock 추가
- [ ] Framebuffer → Lock 추가
- [ ] Keyboard → Lock 추가

### Phase 2: 병렬 실행 API 추가
```swift
// MultiCoreSystem.swift에 추가
func runMultiCoreParallel(maxCycles: Int = 10000) {
    scheduler?.startMultiThreaded(quantum: 4)
    
    // 모든 코어가 종료될 때까지 대기
    while !cores.allSatisfy({ $0.halted }) {
        Thread.sleep(forTimeInterval: 0.001)
        
        if totalCycles >= maxCycles {
            scheduler?.shutdown()
            break
        }
    }
}
```

### Phase 3: 성능 측정
```swift
// 벤치마크 도구
func benchmark() {
    // 순차 실행
    let start1 = Date()
    system.runMultiCore(maxCycles: 10000)
    let sequential = Date().timeIntervalSince(start1)
    
    // 병렬 실행
    let start2 = Date()
    system.runMultiCoreParallel(maxCycles: 10000)
    let parallel = Date().timeIntervalSince(start2)
    
    print("Sequential: \(sequential)s")
    print("Parallel: \(parallel)s")
    print("Speedup: \(sequential / parallel)x")
}
```

---

## 💡 최적화 팁

### 1. Quantum 크기 조정
```swift
// 작은 quantum (4) → 더 자주 동기화, 느림
scheduler.startMultiThreaded(quantum: 4)

// 큰 quantum (100) → 덜 동기화, 빠름 (하지만 응답성 낮음)
scheduler.startMultiThreaded(quantum: 100)
```

### 2. Memory Bus Latency
```swift
// 낮은 latency → 더 많은 충돌
let system = MultiCoreSystem(..., memoryLatency: 1)

// 높은 latency → 적은 충돌, 하지만 느림
let system = MultiCoreSystem(..., memoryLatency: 10)
```

### 3. Cache 활성화
```swift
// 캐시 활성화 → 버스 트래픽 감소
let system = MultiCoreSystem(..., enableCache: true)
```

---

## 🔬 병렬성 검증

### 테스트 1: CPU 사용률 확인
```bash
# 터미널 1: 에뮬레이터 실행
.build/debug/risc-emulator test.bin --cores 8

# 터미널 2: CPU 사용률 모니터링
top -pid <emulator_pid>

# 기대 결과:
# - 순차 실행: CPU 사용률 ~100% (1개 코어)
# - 병렬 실행: CPU 사용률 ~800% (8개 코어)
```

### 테스트 2: 벤치마크
```swift
// Examples/benchmark.s
// 각 코어가 오래 실행되는 작업 수행

_start:
    li x10, 1000000
loop:
    addi x10, x10, -1
    bnez x10, loop
    ebreak
```

```bash
# 1개 코어
time .build/debug/risc-emulator benchmark.bin --cores 1
# → 예: 10초

# 4개 코어 (순차)
time .build/debug/risc-emulator benchmark.bin --cores 4
# → 예: 40초 (4배 느림)

# 4개 코어 (병렬)
time .build/debug/risc-emulator benchmark.bin --cores 4 --parallel
# → 예: 12초 (약 4배 빠름, 약간의 오버헤드)
```

---

## 🚨 주의사항

### 1. Race Condition 방지
```swift
// ❌ 잘못된 예
var counter = 0  // 여러 코어가 동시 접근
core0: counter += 1
core1: counter += 1
// → counter가 1일 수도, 2일 수도 있음

// ✅ 올바른 예
let lock = NSLock()
lock.lock()
counter += 1
lock.unlock()
```

### 2. Deadlock 방지
```swift
// ❌ 잘못된 예
lock1.lock()
lock2.lock()  // 다른 스레드가 반대 순서로 잠금
lock2.unlock()
lock1.unlock()

// ✅ 올바른 예
// 항상 같은 순서로 잠금
lock1.lock()
lock2.lock()
lock2.unlock()
lock1.unlock()
```

### 3. Atomic 주기 결정
```swift
// Quantum이 너무 작으면:
// - 컨텍스트 스위칭 오버헤드 증가
// - 느려짐

// Quantum이 너무 크면:
// - 한 프로세스가 오래 실행
// - 다른 프로세스 기아 상태
```

---

## 📈 예상 성능

### 이상적인 경우
```
코어 수: N
순차 실행 시간: T
병렬 실행 시간: T/N (완벽한 병렬화)
속도 향상: N배
```

### 현실적인 경우
```
동기화 오버헤드: ~5-10%
메모리 버스 충돌: ~10-20%
실제 속도 향상: N * 0.7배 ~ N * 0.85배

예: 4코어
- 이상적: 4배
- 현실적: 2.8배 ~ 3.4배
```

---

## ✅ 체크리스트

프로젝트를 병렬 실행 가능하게 만들기 위한 체크리스트:

- [x] SharedMemory thread-safe
- [x] MemoryBus thread-safe
- [x] Timer thread-safe + 사이클 기반
- [x] UART thread-safe
- [ ] Framebuffer thread-safe
- [ ] Keyboard thread-safe
- [ ] MultiCoreSystem.runMultiCoreParallel() 구현
- [ ] 벤치마크 도구 작성
- [ ] 성능 측정 및 문서화
- [ ] main.swift에 --parallel 플래그 추가

---

**작성일**: 2026-02-07  
**상태**: 진행 중 (50%)  
**다음 단계**: Framebuffer, Keyboard thread-safe 구현
