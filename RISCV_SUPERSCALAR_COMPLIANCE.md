# RISC-V 규격과 슈퍼스칼라 구현

## ✅ 핵심 답변: 완전히 가능합니다!

### ISA vs 마이크로아키텍처 분리

```
┌─────────────────────────────────────────┐
│  RISC-V ISA (명령어 집합 규격)           │
│  - 명령어 형식, 인코딩                   │
│  - 레지스터 (x0-x31, f0-f31, CSR)       │
│  - 메모리 모델 (순서, 일관성)            │
│  - 프로그래머가 보는 인터페이스          │
│  ▲                                      │
│  │ 이 규격만 준수하면 됨                 │
│  │                                      │
└──┼──────────────────────────────────────┘
   │
   │ 내부 구현은 자유!
   │
┌──▼──────────────────────────────────────┐
│  마이크로아키텍처 (구현 방법)            │
│  - 단일 사이클 / 파이프라인              │
│  - In-order / Out-of-order              │
│  - Single-issue / Superscalar           │
│  - 캐시 구조, 분기 예측 등               │
└─────────────────────────────────────────┘
```

---

## 🎯 RISC-V가 슈퍼스칼라에 유리한 이유

### 1. 고정 길이 명령어 (32-bit)
```
ARM:     가변 길이 (16/32-bit Thumb)
x86:     가변 길이 (1-15 bytes) → Fetch가 복잡
RISC-V:  고정 32-bit → 한 사이클에 여러 명령어 Fetch 쉬움
```

**슈퍼스칼라 이점**:
- 4-wide fetch: 128 bits (16 bytes) → 정확히 4개 명령어
- 디코드 단순: 모든 명령어가 같은 길이
- 정렬 예측 가능: PC + 4n

### 2. 간단한 명령어 형식 (6가지만)
```
R-type:  reg-reg 연산
I-type:  immediate 연산
S-type:  store
B-type:  branch
U-type:  upper immediate
J-type:  jump

→ 디코더 단순 → 여러 디코더 병렬 배치 쉬움
```

**x86과 비교**:
```
x86:     수백 가지 명령어 형식 → 디코더 복잡
         마이크로코드 필요한 명령어 존재
RISC-V:  6가지 형식 → 하드웨어 디코더만으로 충분
```

### 3. Load/Store 아키텍처
```
RISC-V:  메모리 접근은 LOAD/STORE만
         ALU는 레지스터만 사용
         
→ 메모리 의존성 명확 → 병렬 실행 쉬움
```

**예시**:
```assembly
# RISC-V
ld   x1, 0(x2)    # Memory
add  x3, x4, x5   # ALU (독립적!)
mul  x6, x7, x8   # ALU (독립적!)
→ 동시 실행 가능

# x86 (CISC)
add  eax, [ebx]   # Memory + ALU 섞임
                   # 내부에서 분리 필요
```

---

## 🏭 실제 RISC-V 슈퍼스칼라 구현 사례

### 1. SiFive U74 (상용 제품)
```
아키텍처: Dual-issue, in-order
IPC: 최대 2.0
특징:
  - 2-wide fetch/decode
  - 2개 execution pipelines
  - Branch prediction (gshare)
  - L1 cache: 32KB I$ + 32KB D$
```

### 2. BOOM (Berkeley Out-of-Order Machine)
```
아키텍처: 4-wide, out-of-order
IPC: 최대 4.0+
특징:
  - 4-wide fetch/decode/issue/retire
  - Reorder buffer (96 entries)
  - Register renaming (96 physical regs)
  - Tournament branch predictor
```
**GitHub**: https://github.com/riscv-boom/riscv-boom

### 3. Rocket Chip (기본 구현)
```
아키텍처: Single-issue, in-order
IPC: 최대 1.0
특징:
  - 5-stage pipeline
  - Simple predictor
  - 기준선으로 많이 사용
```

### 4. XiangShan (중국 과학원)
```
아키텍처: 6-wide, out-of-order
IPC: 최대 6.0+
특징:
  - 6-wide superscalar
  - 256-entry ROB
  - 192 physical registers
  - 성능: ARM Cortex-A76 수준
```

---

## 📐 ISA 규격 준수 포인트

### 반드시 지켜야 하는 것
```
✅ 명령어 실행 결과 (최종 레지스터/메모리 값)
✅ 프로그램 순서 (program order semantics)
✅ 메모리 일관성 모델
✅ 예외/인터럽트 정확한 처리
✅ CSR 동작
```

### 자유롭게 구현 가능한 것
```
✅ 파이프라인 단계 수 (5단, 10단, 15단...)
✅ 슈퍼스칼라 width (1-wide, 2-wide, 4-wide...)
✅ Out-of-order execution
✅ 분기 예측 알고리즘
✅ 캐시 크기/구조
✅ 실행 시간 (빠르면 빠를수록 좋음!)
```

---

## 🔬 우리 구현에서 ISA 준수 방법

### Reorder Buffer의 역할
```swift
// 슈퍼스칼라: 명령어를 순서 상관없이 실행
execute() {
    // 명령어 A, B, C가 있고
    // C가 먼저 끝날 수 있음 (out-of-order execution)
    if instructionC.ready {
        execute(C)  // C 먼저 실행!
    }
}

// BUT: Retire는 반드시 프로그램 순서대로
retire() {
    while !reorderBuffer.isEmpty {
        let rob = reorderBuffer.first!
        
        if rob.completed {
            // 프로그램 순서대로만 commit
            registers[rob.rd] = rob.result
            reorderBuffer.removeFirst()
        } else {
            break  // 순서 유지!
        }
    }
}
```

**결과**: 
- 내부적으로는 빠르게 실행 (슈퍼스칼라)
- 외부에서 보면 순차 실행과 동일 (ISA 준수)

### 메모리 순서 보장
```swift
class LoadStoreQueue {
    // Store는 순서대로만 메모리에 쓰기
    func commitStore() {
        // ROB head가 store일 때만 실제 메모리에 쓰기
        if reorderBuffer.first!.isStore {
            memory.write(address, data)
        }
    }
    
    // Load는 이전 Store 확인
    func executeLoad(address: UInt64) {
        // 같은 주소에 pending store 있으면 forwarding
        if let pendingStore = findPendingStore(address) {
            return pendingStore.data  // Store-to-load forwarding
        } else {
            return memory.read(address)
        }
    }
}
```

---

## 💡 실제 RISC-V 프로세서 스펙트럼

```
Simple (IPC ~1.0)        Moderate (IPC ~2.0)      High-end (IPC ~4.0+)
│                        │                        │
Rocket Chip              SiFive U74               BOOM
│                        │                        │
- 1-wide                 - 2-wide                 - 4-wide
- In-order               - In-order               - Out-of-order
- 5-stage                - 8-stage                - 12+ stage
- 간단                   - 상용 제품              - 연구/고성능
│                        │                        │
└────────────────────────┴────────────────────────┘
        모두 동일한 RISC-V ISA!
```

---

## 🎯 결론

### RISC-V + 슈퍼스칼라 = 완벽한 조합

**RISC-V 설계 철학**:
- ISA는 단순하고 명확하게 (프로그래머 편의)
- 구현은 자유롭게 (하드웨어 혁신 허용)

**우리 구현**:
```
✅ ISA 준수: 프로그램 순서, 결과 보장 (ROB)
✅ 성능 향상: 2-wide 슈퍼스칼라 (IPC 2.0 목표)
✅ 호환성: 기존 RISC-V 바이너리 그대로 실행
✅ 투명성: 소프트웨어는 슈퍼스칼라 인지 못함
```

**비유**:
```
ISA = 도로 교통 규칙
    (어디로 가야 하는가)

슈퍼스칼라 = 자동차 엔진
    (얼마나 빨리 가는가)

규칙만 지키면 Ferrari든 Truck이든 OK!
```

---

## 📚 참고자료

**RISC-V ISA Manual**:
https://riscv.org/technical/specifications/

**BOOM (Berkeley Out-of-Order Machine)**:
https://github.com/riscv-boom/riscv-boom

**SiFive Core IP**:
https://www.sifive.com/cores

**논문**:
- "The Berkeley Out-of-Order Machine (BOOM): An Industry-Competitive, Synthesizable, Parameterized RISC-V Processor"
- "Rocket Chip Generator: A Parameterizable SoC Generator"

---

*작성일: 2026-02-14*
*핵심: ISA = 규격, 슈퍼스칼라 = 구현 기술*
