# MMIO 최적화 가이드

## 🎯 개선 내용

### 문제점
```
현재 FramebufferDevice:
  - 모든 read/write에 NSLock 사용
  - 단일 픽셀 쓰기마다 lock/unlock
  - Framebuffer clear: 98,304번 반복 × lock overhead
  - 결과: 5M cycles (이론값 대비 7.3배)
```

### 해결책
```
FramebufferDeviceOptimized:
  ✅ Bulk write API - 대량 쓰기를 한 번에
  ✅ Lock-free reads - 읽기는 잠금 없음
  ✅ UnsafeMutablePointer - 연속 메모리, 빠른 접근
```

---

## 📊 성능 비교

### Before (NSLock 기반)
```swift
func write32(offset: UInt64, value: UInt32) -> Bool {
    lock.lock()           // 비용 발생
    defer { lock.unlock() }
    pixels[index] = value
    return true
}

// Framebuffer clear (98,304 pixels):
// 98,304 × (lock + unlock) = 매우 느림
```

### After (최적화)
```swift
// 1. Lock-free reads
func read32(offset: UInt64) -> UInt32? {
    // No lock!
    return pixelBuffer[pixelIndex]
}

// 2. Bulk write
func writeBulk(offset: UInt64, data: [UInt32]) -> Bool {
    writeLock.lock()      // 단 한 번만!
    defer { writeLock.unlock() }
    
    for (i, value) in data.enumerated() {
        pixelBuffer[startIndex + i] = value
    }
    return true
}

// 3. Optimized clear
func clear(color: UInt32) {
    writeLock.lock()      // 단 한 번만!
    defer { writeLock.unlock() }
    
    pixelBuffer.update(repeating: color, count: pixelCount)
}
```

---

## 🚀 예상 성능 향상

### Framebuffer Clear
```
Before:  5,000,000 cycles (98,304 locks)
After:   1,500,000 cycles (1 lock)
Improvement: 70% faster
```

### Read Operations
```
Before:  Lock contention on every read
After:   Lock-free (no contention)
Improvement: 90%+ for concurrent reads
```

### Memory Usage
```
Before:  Array<UInt32> (heap allocation)
After:   UnsafeMutablePointer (contiguous)
Benefit: Better cache locality
```

---

## 🔧 통합 방법

### Option 1: Replace FramebufferDevice (추천)
```swift
// MultiCoreSystem.swift 수정
let framebuffer = FramebufferDeviceOptimized()
memoryBus.registerMMIO(device: framebuffer)
```

### Option 2: Add as Alternative
```swift
// main.swift에 옵션 추가
var useFastFramebuffer = arguments.contains("--fast-fb")

if useFastFramebuffer {
    let fb = FramebufferDeviceOptimized()
    memoryBus.registerMMIO(device: fb)
} else {
    let fb = FramebufferDevice()
    memoryBus.registerMMIO(device: fb)
}
```

---

## 🧪 테스트 방법

### 자동 테스트
```bash
chmod +x test_mmio_optimization.sh
./test_mmio_optimization.sh
```

### 수동 비교
```bash
# 1. 기존 구현으로 테스트
./build_kernel.sh
time ./bin/risc-emulator kernel/kernel.bin --max-cycles 10000000

# 2. 최적화 버전으로 테스트 (통합 후)
time ./bin/risc-emulator kernel/kernel.bin --max-cycles 10000000 --fast-fb

# 비교: cycle 수와 실제 실행 시간
```

---

## 💡 추가 최적화 가능

### 1. Store Buffer (더 나아가기)
```swift
class StoreBuffer {
    var pendingWrites: [(offset: UInt64, value: UInt32)] = []
    let capacity = 16
    
    func add(offset: UInt64, value: UInt32) {
        if pendingWrites.count >= capacity {
            flush()
        }
        pendingWrites.append((offset, value))
    }
    
    func flush() {
        // Bulk commit all pending writes
        writeLock.lock()
        for (offset, value) in pendingWrites {
            pixelBuffer[index] = value
        }
        writeLock.unlock()
        pendingWrites.removeAll()
    }
}
```

### 2. Double Buffering
```swift
class DoubleBufferedFramebuffer {
    var frontBuffer: UnsafeMutablePointer<UInt32>
    var backBuffer: UnsafeMutablePointer<UInt32>
    
    func swap() {
        // Atomic swap
        (frontBuffer, backBuffer) = (backBuffer, frontBuffer)
    }
}
```

### 3. Atomic Operations (완전 Lock-Free)
```swift
import Atomics

class AtomicFramebuffer {
    var pixels: [ManagedAtomic<UInt32>]
    
    func write32(offset: UInt64, value: UInt32) -> Bool {
        pixels[index].store(value, ordering: .relaxed)
        return true
    }
    
    func read32(offset: UInt64) -> UInt32? {
        return pixels[index].load(ordering: .relaxed)
    }
}
```

---

## 📈 실제 사용 예시

### Kernel에서 Bulk Write 활용
```assembly
# 기존 방식 (느림)
li t0, FB_BASE
li t1, 786432
loop:
    sw a0, 0(t0)      # 각각 lock
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, loop

# 최적화 방식 (빠름)
# Kernel이 블록 단위로 준비 후 한번에 전송
# 또는 커널 term_clear 함수가 bulk write 사용
```

### Swift Terminal에서
```swift
// 기존
for pixel in pixels {
    framebuffer.write32(offset: offset, value: pixel)
    offset += 4
}

// 최적화
framebuffer.writeBulk(offset: startOffset, data: pixels)
```

---

## ⚠️ 주의사항

### Thread Safety
```
✅ Reads: Lock-free (safe for concurrent reads)
✅ Writes: Lock 사용 (serialized)
⚠️ Read-Write: Memory barriers 고려 필요
```

### Memory Ordering
```swift
// 필요시 memory barrier 추가
func write32(offset: UInt64, value: UInt32) -> Bool {
    writeLock.lock()
    pixelBuffer[index] = value
    OSMemoryBarrier()  // Ensure visibility
    writeLock.unlock()
    return true
}
```

---

## 📚 성능 측정 결과 (예상)

### Test Case: Framebuffer Clear
```
Baseline (CoreSimple + FramebufferDevice):
  - Cycles: 5,000,000
  - Time: ~500ms (1 GHz assumed)
  
Optimized (CoreSimple + FramebufferDeviceOptimized):
  - Cycles: 1,500,000
  - Time: ~150ms
  - Improvement: 70% faster
  
With Store Buffer:
  - Cycles: 1,000,000
  - Time: ~100ms
  - Improvement: 80% faster
```

---

## 🎯 다음 단계

### Phase 1 (현재)
- [x] FramebufferDeviceOptimized 구현
- [ ] MultiCoreSystem 통합
- [ ] 성능 테스트 및 검증

### Phase 2
- [ ] Store Buffer 추가
- [ ] Double Buffering
- [ ] 다른 MMIO 디바이스 최적화

### Phase 3
- [ ] 완전 Lock-free (Atomic)
- [ ] NUMA-aware 최적화
- [ ] GPU 가속 고려

---

*작성일: 2026-02-14*
*목표: Framebuffer clear 5M → 1.5M cycles (70% 향상)*
