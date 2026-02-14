# 2-bit 분기 예측기 구현

## 날짜
2026-02-14

## 개요
분기 명령어의 taken/not-taken을 2-bit saturating counter로 예측하여 파이프라인 stall 감소.

## 분기 예측이란?

### 문제: 분기 딜레마
```
beq x1, x2, target    # if (x1 == x2) goto target

파이프라인 관점:
Cycle 1: [Fetch] beq
Cycle 2: [Decode] 
Cycle 3: [Execute] → 이제야 결과 알게 됨!
Cycle 4: [Fetch] ??? 어디서 fetch?
```

**해결책:** 분기 결과를 기다리지 말고 **예측**해서 미리 fetch.

### 예측 방식 비교

| 방식 | 정확도 | 복잡도 |
|------|--------|--------|
| **Always Not-Taken** | ~50% | 매우 낮음 |
| **1-bit Predictor** | ~70% | 낮음 |
| **2-bit Predictor** | ~85-95% | 중간 |
| **Two-level Adaptive** | ~95-98% | 높음 |

## 2-bit Saturating Counter

### 상태 머신

```
    taken        taken        taken
  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
  │ Strong  │→│  Weak   │→│  Weak   │→│ Strong  │
  │Not-Taken│←│Not-Taken│←│  Taken  │←│  Taken  │
  └─────────┘ └─────────┘ └─────────┘ └─────────┘
   not-taken   not-taken   not-taken   not-taken
       00          01          10          11

예측:
  - State 00, 01 → predict NOT-TAKEN
  - State 10, 11 → predict TAKEN

특징:
  - 한 번의 오예측으로는 예측 방향 안 바뀜 (안정적)
```

### 예시: 루프

```c
for (int i = 0; i < 100; i++) {
    // ...
}
```

**분기 패턴:**
```
beq (i == 100):
  1~99회: not-taken (계속 루프)
  100회: taken (종료)
```

**2-bit Predictor 동작:**
```
초기 상태: Weak Not-Taken (01)

1회: 예측 NOT-TAKEN ✓ → 상태: Strong Not-Taken (00)
2~99회: 예측 NOT-TAKEN ✓ → 상태 유지 (00)
100회: 예측 NOT-TAKEN ✗ → 상태: Weak Not-Taken (01)

정확도: 99/100 = 99%
```

## 구현 세부사항

### 1. BranchPredictor.swift (신규)

**핵심 구조:**
```swift
class TwoBitBranchPredictor {
    enum State: UInt8 {
        case strongNotTaken = 0
        case weakNotTaken = 1
        case weakTaken = 2
        case strongTaken = 3
    }
    
    private var table: [UInt64: State] = [:]  // PC → State
    
    func predict(pc: UInt64) -> Bool
    func update(pc: UInt64, actualTaken: Bool)
}
```

**메모리 사용:**
- Entry: 8 bytes (PC) + 1 byte (State) = 9 bytes
- 1024 unique branches: ~9 KB
- 충분히 작음

### 2. CoreSimple.swift (수정)

**executeBType 수정:**
```swift
private func executeBType(...) {
    // 1. 예측
    let predicted = branchPredictor.predict(pc: pc)
    
    // 2. 실제 분기 조건 계산
    let taken = (a == b)  // or other conditions
    
    // 3. 예측기 업데이트
    branchPredictor.update(pc: pc, actualTaken: taken)
    
    // 4. 오예측 추적
    if predicted != taken {
        branchMispredictions += 1
    }
    
    // 5. 실제 분기 실행
    if taken {
        self.pc = target
    }
}
```

**통계 출력:**
```swift
func printStatus() {
    print("Branch Predictor:")
    print("  Predictions: \(branchPredictor.predictions)")
    print("  Correct: \(branchPredictor.correct)")
    print("  Accuracy: \(branchPredictor.accuracy)%")
    print("  Unique Branches: \(branchPredictor.uniqueBranches)")
}
```

## 예상 성능 향상

### 분기 패턴별 정확도

| 패턴 | 정확도 |
|------|--------|
| **Loops (반복문)** | 95-99% |
| **If-else (단순)** | 85-90% |
| **Switch-case** | 70-80% |
| **Random** | 50% (worst case) |

### 전체 성능 영향

**가정:**
- 전체 명령어 중 분기: 15-20%
- 파이프라인 코어: 분기 미스페널티 3 cycles
- 순차 실행 코어: 효과 제한적 (통계만)

**파이프라인 코어 (이상적):**
```
Before: 20% branches × 3 cycle penalty = 0.6 CPI overhead
After: 20% branches × 10% miss rate × 3 cycles = 0.06 CPI overhead

성능 향상: (1.6 - 1.06) / 1.6 = 33% faster
```

**순차 실행 코어 (Leenux 현재):**
```
직접적 성능 향상 없음 (파이프라인 없음)
→ 향후 파이프라인 구현 시 준비
```

## 테스트 방법

### 예상 출력
```
Core 0 Status:
  PC: 0x1234
  Cycles: 5,000,000
  Instructions: 5,000,000
  CPI: 1.00
  Branches: 850,000 taken, 150,000 not taken

  Branch Predictor:
    Predictions: 1,000,000
    Correct: 920,000
    Incorrect: 80,000
    Accuracy: 92.0%
    Unique Branches: 240
```

### 검증 체크리스트
- [ ] 빌드 성공
- [ ] 분기 예측 통계 출력
- [ ] 정확도 > 85%
- [ ] Unique branches > 0

## 제한 사항

### 순차 실행 코어 (현재)
- **직접적 성능 향상 없음**
- 파이프라인이 없어서 예측해도 활용 못 함
- 통계만 수집 (학습/분석 목적)

### 향후 적용
- Pipeline.swift에 통합하면 진정한 효과
- 파이프라인 flush 방지
- CPI 개선

## 개선 방향

1. **Local History Predictor**
   - PC별 분기 히스토리 저장
   - 패턴 기반 예측

2. **Global History Predictor**
   - 전체 분기 히스토리 사용
   - 상관관계 활용

3. **Hybrid Predictor**
   - Local + Global 조합
   - 95%+ 정확도

## 변경 파일

- `risc/Sources/BranchPredictor.swift` (신규)
- `risc/Sources/CoreSimple.swift` (수정)

---

**작성자:** 김서방 (AI)  
**검토자:** 용 이  
**버전:** 1.0
