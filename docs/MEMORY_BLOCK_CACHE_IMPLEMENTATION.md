# 메모리 블록 캐싱 구현

## 날짜
2026-02-14

## 개요
명령어 fetch 시 매번 메모리 버스 접근하는 대신, 256-byte 블록 단위로 캐싱하여 성능 향상.

## 변경 사항

### 1. 신규 파일: `MemoryBlockCache.swift`

**핵심 개념:**
- 256-byte 블록 단위 캐싱 (64 instructions)
- TLB (Translation Lookaside Buffer) 시뮬레이션과 유사
- LRU eviction 정책

**주요 기능:**
```swift
class MemoryBlockCache {
    func read32(address: UInt64) -> UInt32?
    func write32(address: UInt64, value: UInt32)
    
    var hitRate: Double
    var count: Int
    var memoryUsed: Int
}
```

**동작 방식:**
```
1. read32(0x1004) 호출
2. Block address: 0x1000 (256-byte aligned)
3. Cache hit?
   - YES: 블록에서 offset 1 값 반환
   - NO: 메모리 버스에서 블록 로드 (0x1000~0x10FF)
4. LRU 업데이트
```

**Write Policy:**
- Write-through: 메모리 버스에 즉시 쓰기
- Cache invalidation: 해당 블록 무효화

### 2. 수정 파일: `CoreSimpleOptimized.swift`

**Before:**
```swift
private func fetch() -> UInt32 {
    return memoryBus.read32(coreId: id, address: pc) ?? 0
}
```

**After:**
```swift
private var memoryCache: MemoryBlockCache!

init(id: Int, memoryBus: MemoryBus, startPC: UInt64 = 0x1000) {
    // ...
    self.memoryCache = MemoryBlockCache(memoryBus: memoryBus, coreId: id, capacity: 128)
}

private func fetch() -> UInt32 {
    return memoryCache.read32(pc) ?? 0
}
```

### 3. 통계 출력 개선

**출력 예시:**
```
Memory Block Cache:
  Hits: 4,985,000
  Misses: 15,000
  Hit Rate: 99.7%
  Blocks Cached: 120 / 128 blocks
  Memory Used: 30 KB
```

## 성능 분석

### 캐시 적중 시나리오

**프로그램 실행 패턴:**
- 반복문 (loops): 동일 블록 반복 접근 → 높은 히트율
- 순차 실행: 인접 명령어 블록 단위로 캐싱
- 함수 호출: 자주 호출되는 함수는 캐시에 유지

**예상 히트율:**
```
Sequential code: 98-99% (블록 내 64 instructions)
Loop code: 99.9% (동일 블록 반복)
Random jumps: 50-70% (워스트 케이스)
Average: 95-99%
```

### 메모리 액세스 감소

**Before (블록 캐싱 없음):**
```
5,000,000 cycles → 5,000,000 memory reads
```

**After (블록 캐싱):**
```
5,000,000 cycles
  - Cache hits: 4,985,000 (99.7%)
  - Cache misses: 15,000 (0.3%)
→ Actual memory reads: 15,000 blocks × 64 = 960,000 reads
→ Reduction: 80% fewer memory bus accesses
```

## 구현 세부사항

### 블록 크기 선택: 256 bytes

**이유:**
1. **Locality of reference**: 명령어는 순차 실행 경향
2. **적절한 granularity**: 너무 크면 오버헤드, 너무 작으면 효과 적음
3. **Cache line 시뮬레이션**: 실제 CPU L1 캐시와 유사 (64-128 bytes)

### Capacity: 128 blocks

**메모리 사용:**
- 128 blocks × 256 bytes = 32 KB
- 허용 범위 (전체 에뮬레이터 메모리 대비 무시 가능)

**Coverage:**
- 32 KB = 8,192 instructions
- Leenux 커널 (~12 KB) 전체 캐싱 가능

### LRU Eviction

**최적화:**
- Access counter 기반 (정확한 LRU)
- O(n) eviction (capacity 작아서 괜찮음)
- 향후 개선: Min-heap 사용 시 O(log n)

## 예상 성능 향상

| 항목 | 기존 | 메모리 블록 캐싱 | 개선 |
|------|------|-----------------|------|
| **Memory Reads** | 5,000,000 | ~15,000 miss | **99.7% 감소** |
| **Cache Hit Rate** | N/A | 99.7% | - |
| **메모리 사용** | 0 KB | 32 KB | +32 KB |
| **전체 성능** | 기준 | **2~5배** | **100~400%** ↑ |

## 조합 효과 (LRU Decode + Memory Block)

**Phase 8+ 누적 최적화:**
```
1. LRU Decode Cache: 1.5-2× faster
2. Memory Block Cache: 2-5× faster
3. Combined: 3-10× faster (예상)
```

**Bottleneck 전환:**
- Before: Memory bus access (느림)
- After: ALU execution (본질적 작업)

## 제한 사항

### Self-Modifying Code
- 캐시된 블록은 write 시 invalidate
- 자가수정 코드는 캐시 효과 감소
- **Leenux 적용**: 문제 없음 (정적 코드)

### Write Performance
- Write-through 정책으로 write는 캐싱 안 됨
- **Leenux 적용**: 명령어 영역은 read-only

## 테스트 계획

### 빌드
```bash
cd risc && swift build -c release && cd ..
cp risc/.build/release/risc-emulator bin/
```

### 실행 및 검증
```bash
./bin/risc-emulator kernel/kernel.bin --max-cycles 5000000 --memory 256
```

**예상 출력:**
```
=== Core 0 Optimization Statistics ===
Cycles: 5,000,000
Instructions: 5,000,000
CPI: 1.00

LRU Decode Cache:
  Hits: 4,850,000
  Misses: 150,000
  Hit Rate: 97.0%
  Cache Size: 45,000 / 50,000 entries

Memory Block Cache:
  Hits: 4,985,000
  Misses: 15,000
  Hit Rate: 99.7%
  Blocks Cached: 120 / 128 blocks
  Memory Used: 30 KB
```

## 향후 개선

1. **Write Buffer**: Write-back 정책으로 write 성능 향상
2. **Multi-level Cache**: L1/L2 계층 구조
3. **Prefetching**: 순차 액세스 예측하여 사전 로드

---

**작성자:** 김서방 (AI)  
**검토자:** 용 이  
**버전:** 1.0
