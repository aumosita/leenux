# 호스트 시스템 활용 에뮬레이터 최적화

## 🎯 핵심 아이디어

```
파이프라인/슈퍼스칼라: RISC-V를 복잡하게 (❌ 폐기)
호스트 활용: Swift/에뮬레이터를 빠르게 (✅ 실용적)
```

**목표**: 같은 RISC-V 명령어를 더 빠르게 에뮬레이션

---

## 🚀 즉시 적용 가능한 최적화

### 1. 명령어 배치 실행 (Block Execution) ⚡

**현재**:
```swift
func tick() {
    // 한 명령어 실행
    fetch()
    decode()
    execute()
}
```

**최적화**:
```swift
func executeBatch(count: Int = 1000) {
    var executed = 0
    
    // 1000개 명령어를 한번에 실행
    while executed < count && !halted {
        // Fetch multiple
        let instructions = fetchMultiple(16)  // 16개 미리 fetch
        
        // Decode multiple
        for instr in instructions {
            executeInstruction(instr)
            executed += 1
            if halted { break }
        }
    }
}
```

**효과**: 
- 함수 호출 오버헤드 감소
- 루프 최적화
- 예상 향상: 20-30%

---

### 2. 디코드 캐싱 (Instruction Cache) 🎯

**문제**: 같은 명령어를 반복 디코딩
```swift
// 루프에서 같은 명령어 1000번 디코딩
while i < 1000 {
    let decoded = Instruction.decode(0x00A50533)  // 매번 디코딩!
}
```

**해결**:
```swift
class DecodedInstructionCache {
    private var cache: [UInt32: Instruction] = [:]
    
    func decode(_ raw: UInt32) -> Instruction {
        if let cached = cache[raw] {
            return cached  // 캐시 히트!
        }
        
        let decoded = Instruction.decode(raw: raw)
        cache[raw] = decoded
        return decoded
    }
}
```

**효과**: 
- 루프에서 90%+ 캐시 히트
- 디코딩 오버헤드 제거
- 예상 향상: 30-40%

---

### 3. Direct Threaded Interpreter 🔥

**현재 (Switch-based)**:
```swift
switch instruction {
case .rType:
    executeRType()  // 분기 예측 실패 가능
case .iType:
    executeIType()
case .sType:
    executeSType()
// ...
}
```

**최적화 (Function pointer table)**:
```swift
typealias InstructionHandler = (DecodedInstruction) -> Void

class DirectThreadedCore {
    var dispatchTable: [InstructionHandler]
    
    init() {
        dispatchTable = [
            handleADD,
            handleSUB,
            handleLD,
            // ... 모든 명령어
        ]
    }
    
    func execute(_ instr: DecodedInstruction) {
        dispatchTable[instr.opcode](instr)  // Direct jump!
    }
}
```

**효과**:
- 분기 예측 미스 감소
- CPU 파이프라인 효율 향상
- 예상 향상: 15-25%

---

### 4. SIMD 활용 (메모리 클리어) 💨

**현재**:
```swift
func clear(color: UInt32) {
    for i in 0..<pixelCount {
        pixels[i] = color  // 하나씩
    }
}
```

**SIMD 최적화**:
```swift
import simd

func clear(color: UInt32) {
    let simdColor = SIMD8<UInt32>(repeating: color)
    
    var i = 0
    // Process 8 pixels at once
    while i + 8 <= pixelCount {
        let ptr = pixelBuffer.advanced(by: i)
        ptr.withMemoryRebound(to: SIMD8<UInt32>.self, capacity: 1) { simdPtr in
            simdPtr.pointee = simdColor
        }
        i += 8
    }
    
    // Handle remaining
    while i < pixelCount {
        pixelBuffer[i] = color
        i += 1
    }
}
```

**효과**:
- 8배 병렬 처리
- CPU SIMD 명령어 활용
- 예상 향상: 5-8배 (특정 작업)

---

### 5. 멀티스레드 메모리 접근 최적화 🔀

**현재 문제**: Lock 경합

**해결**:
```swift
class PartitionedMemory {
    // 메모리를 여러 파티션으로 분할
    var partitions: [MemoryPartition] = []
    
    init(size: Int, partitionCount: Int = 4) {
        let partitionSize = size / partitionCount
        for i in 0..<partitionCount {
            partitions.append(MemoryPartition(
                start: i * partitionSize,
                size: partitionSize
            ))
        }
    }
    
    func read(address: UInt64) -> UInt8? {
        let partition = getPartition(address)
        return partition.read(address)  // 각 파티션별 lock
    }
}

class MemoryPartition {
    private var data: [UInt8]
    private let lock = NSLock()  // 파티션별 lock
    
    func read(_ addr: UInt64) -> UInt8? {
        // lock 경합 감소
        lock.lock()
        defer { lock.unlock() }
        return data[Int(addr)]
    }
}
```

**효과**:
- Lock 경합 75% 감소
- 병렬 접근 향상
- 예상 향상: 40-60% (멀티코어)

---

### 6. Profile-Guided Optimization (PGO) 📊

**방법**:
```bash
# 1. Profile 수집
swift build -c release -Xswiftc -profile-generate

# 2. 실제 워크로드 실행
./bin/risc-emulator kernel/kernel.bin --max-cycles 10000000

# 3. Profile 기반 최적화 빌드
swift build -c release -Xswiftc -profile-use=default.profdata
```

**효과**:
- 자주 실행되는 코드 최적화
- 분기 예측 개선
- 인라이닝 최적화
- 예상 향상: 10-20%

---

### 7. 메모리 풀링 (Object Pooling) 🏊

**현재 문제**: 빈번한 할당/해제

**해결**:
```swift
class InstructionPool {
    private var pool: [Instruction] = []
    private let capacity = 1000
    
    func acquire() -> Instruction {
        if let instr = pool.popLast() {
            return instr
        }
        return Instruction()  // 새로 생성
    }
    
    func release(_ instr: Instruction) {
        if pool.count < capacity {
            pool.append(instr)
        }
    }
}

// 사용
let instr = pool.acquire()
// ... 사용
pool.release(instr)  // 재활용
```

**효과**:
- GC 압력 감소
- 할당 오버헤드 제거
- 예상 향상: 5-10%

---

### 8. Lazy Evaluation (지연 평가) 🦥

**현재**:
```swift
func executeADD(rd: UInt8, rs1: UInt8, rs2: UInt8) {
    registers[rd] = registers[rs1] + registers[rs2]
    
    // 매번 체크
    registers[0] = 0  // x0 always zero
}
```

**최적화**:
```swift
func executeADD(rd: UInt8, rs1: UInt8, rs2: UInt8) {
    if rd == 0 { return }  // Early exit
    
    registers[rd] = registers[rs1] + registers[rs2]
}

// 별도로 주기적으로만 체크
func cleanupRegisters() {
    registers[0] = 0
}
```

**효과**:
- 불필요한 작업 제거
- 예상 향상: 2-5%

---

## 🎯 통합 최적화 전략

### Phase 1: Quick Wins (1주)
```swift
class OptimizedCore {
    let decodeCache = DecodedInstructionCache()
    let instrPool = InstructionPool()
    
    func executeBatch(count: Int = 1000) {
        // Batch execution
        for _ in 0..<count {
            let raw = fetch()
            let decoded = decodeCache.decode(raw)  // 캐싱
            execute(decoded)
        }
    }
}
```

**예상 향상**: 50-70%

### Phase 2: Advanced (2주)
```swift
class SIMDOptimizedCore {
    let directDispatch = DirectThreadedDispatcher()
    let partitionedMemory = PartitionedMemory(size: 256MB)
    
    func executeOptimized() {
        // Direct threading
        // Partitioned memory
        // SIMD operations
    }
}
```

**예상 향상**: 100-150% (2-2.5배)

---

## 📊 예상 성능 향상 (누적)

```
Baseline:                    1.0x (현재)
+ Batch Execution:           1.3x
+ Decode Caching:            1.7x
+ Direct Threading:          2.0x
+ SIMD (특정 작업):          2.5x
+ Partitioned Memory:        3.0x
+ PGO:                       3.3x

최종 목표: 3-4배 속도 향상
```

---

## 🔧 구현 우선순위

### 즉시 (1-2일)
1. **배치 실행** - 가장 쉽고 효과적
2. **디코드 캐싱** - 간단한 딕셔너리 추가

### 1주
3. **MMIO 최적화** (이미 완료!)
4. **메모리 파티셔닝**

### 2주
5. **Direct Threading**
6. **SIMD 최적화**

### 장기
7. **PGO**
8. **JIT 컴파일** (선택)

---

## 💡 실용적 예시

### Framebuffer Clear 최적화 조합

**현재**:
```
5M cycles (MMIO lock overhead)
```

**After 최적화**:
```
1. MMIO Bulk Write:     1.5M cycles (70% ↓)
2. SIMD Clear:          200K cycles (87% ↓)
3. Batch Execution:     150K cycles (25% ↓)

Total: 150K cycles (97% 향상!)
```

---

## 🎯 결론

### 파이프라인 vs 호스트 최적화

```
파이프라인:
  - 복잡도: 매우 높음
  - 버그 가능성: 높음
  - 성능 향상: 2-4배 (이론적)
  ❌ 폐기

호스트 최적화:
  - 복잡도: 낮음-중간
  - 버그 가능성: 낮음
  - 성능 향상: 3-4배 (실용적)
  ✅ 추천!
```

### 추천 순서
1. ✅ MMIO 최적화 (완료)
2. 배치 실행 (1-2일)
3. 디코드 캐싱 (1일)
4. 메모리 파티셔닝 (3-4일)
5. Direct Threading (1주)

---

*작성일: 2026-02-14*
*목표: 에뮬레이터 자체를 3-4배 빠르게*
