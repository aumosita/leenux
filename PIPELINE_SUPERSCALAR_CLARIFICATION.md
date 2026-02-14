# 파이프라인 vs 슈퍼스칼라 명확화

## ⚠️ 중요한 개념 정리

### 슈퍼스칼라 = 파이프라인 필수!

```
❌ 잘못된 이해:
   파이프라인 없이 슈퍼스칼라 가능

✅ 올바른 이해:
   슈퍼스칼라는 파이프라인의 확장
   각 파이프라인 단계에서 여러 명령어를 동시 처리
```

---

## 📊 아키텍처 진화 순서

### 1. 순차 실행 (No Pipeline) - CoreSimple
```
Cycle 1: [Fetch-Decode-Execute-Write] Instr 1
Cycle 2:                               [Fetch-Decode-Execute-Write] Instr 2
Cycle 3:                                                            [Fetch-Decode-Execute-Write] Instr 3

CPI: 4 (명령어당 4 사이클)
처리량: 명령어 1개 / 4 사이클 = 0.25 instr/cycle
```

### 2. 파이프라인 (Pipeline) - Pipeline.swift
```
Cycle 1: [Fetch] Instr 1
Cycle 2: [Decode] [Fetch] Instr 2
Cycle 3: [Execute] [Decode] [Fetch] Instr 3
Cycle 4: [Memory] [Execute] [Decode] [Fetch] Instr 4
Cycle 5: [Write] [Memory] [Execute] [Decode] [Fetch] Instr 5

CPI: 1 (이상적)
처리량: 1 instr/cycle
```

### 3. 슈퍼스칼라 (Superscalar) = 파이프라인 + 병렬
```
Cycle 1: [Fetch Instr1, Instr2]
Cycle 2: [Decode Instr1, Instr2] [Fetch Instr3, Instr4]
Cycle 3: [Execute Instr1, Instr2] [Decode Instr3, Instr4] [Fetch Instr5, Instr6]
Cycle 4: [Memory Instr1, Instr2] [Execute Instr3, Instr4] [Decode Instr5, Instr6] [Fetch Instr7, Instr8]

IPC: 2 (이상적)
처리량: 2 instr/cycle
```

---

## 🔍 현재 Leenux 상태

### CoreSimple.swift
```swift
// 순차 실행 (파이프라인 없음)
func tick() {
    // 한 명령어를 완전히 실행
    fetch()      // 1 cycle
    decode()     // 포함
    execute()    // 포함
    // 다음 명령어로 진행
}

특징:
  - 간단, 디버깅 쉬움
  - CPI: 1-2
  - 파이프라인 없음
```

### Pipeline.swift (이미 존재!)
```swift
// 5단 파이프라인 구현
struct IFIDRegister   // Fetch → Decode 사이
struct IDEXRegister   // Decode → Execute 사이
struct EXMEMRegister  // Execute → Memory 사이
struct MEMWBRegister  // Memory → WriteBack 사이

특징:
  - 5단 파이프라인
  - Hazard detection
  - Forwarding
  - CPI: 1.0 (이상적)
```

### CoreSuperscalar.swift (새로 추가)
```swift
// 파이프라인 기반 슈퍼스칼라
func tick() {
    retire()    // Stage 5 (2-wide)
    execute()   // Stage 4 (2-wide)
    issue()     // Stage 3 (2-wide)
    decode()    // Stage 2 (2-wide)
    fetch()     // Stage 1 (2-wide)
}

특징:
  - 각 단계에서 2개씩 처리
  - 파이프라인 + 병렬
  - IPC: 1.5-2.0 목표
```

---

## 📐 올바른 구조

### 슈퍼스칼라의 필수 요소

```
1. 파이프라인 (필수)
   ├─ Fetch Stage
   ├─ Decode Stage
   ├─ Execute Stage
   ├─ Memory Stage
   └─ Writeback Stage

2. 각 단계의 Width (슈퍼스칼라의 핵심)
   ├─ 1-wide: 단일 발행 (일반 파이프라인)
   ├─ 2-wide: 2개 동시 발행 (슈퍼스칼라)
   ├─ 4-wide: 4개 동시 발행
   └─ 8-wide: 8개 동시 발행

3. Reorder Buffer (순서 보장)
   └─ 파이프라인 결과를 순서대로 commit
```

---

## 🎯 정확한 비교표

| 구조 | 파이프라인 | Width | IPC | 구현 |
|------|-----------|-------|-----|------|
| **순차 실행** | ❌ 없음 | 1 | 0.25 | CoreSimple (일부) |
| **파이프라인** | ✅ 5단 | 1 | 1.0 | Pipeline.swift |
| **슈퍼스칼라** | ✅ 5단 | 2+ | 2.0+ | CoreSuperscalar |
| **OOO 슈퍼스칼라** | ✅ 10+단 | 4+ | 4.0+ | 미구현 |

---

## 🔧 CoreSuperscalar 수정 필요

### 현재 구현의 문제
```swift
// 현재: 버퍼는 있지만 진짜 파이프라인은 아님
func tick() {
    retire()    // 실제로는 즉시 실행
    execute()   // 실제로는 즉시 실행
    issue()
    decode()
    fetch()
}
```

### 진짜 파이프라인으로 수정 필요
```swift
// 수정: 파이프라인 레지스터 추가
struct SuperscalarPipeline {
    var fetchBuffer: [FetchEntry]      // IF stage
    var decodeBuffer: [DecodeEntry]    // ID stage  
    var issueQueue: [IssueEntry]       // IS stage
    var executeUnits: [ExecuteUnit]    // EX stage
    var reorderBuffer: [ROBEntry]      // Retire stage
}

func tick() {
    // 역순으로 처리 (파이프라인 규칙)
    retireStage()     // ROB → Registers
    executeStage()    // Execute → ROB
    issueStage()      // Issue → Execute units
    decodeStage()     // Decode → Issue
    fetchStage()      // Memory → Decode
}
```

---

## 💡 올바른 이해

### 슈퍼스칼라의 정의
```
슈퍼스칼라 = 파이프라인의 각 단계에서 
             여러 명령어를 동시에 처리하는 구조

파이프라인 없이는 슈퍼스칼라 불가능!
```

### 비유
```
파이프라인:
  공장 조립 라인 (각 단계별로 작업)
  
슈퍼스칼라:
  각 조립 라인에 작업자 2명씩 배치
  (동시에 2개씩 조립)
  
파이프라인 없이 슈퍼스칼라:
  ❌ 말이 안 됨! 조립 라인 없이 
     동시 조립 불가능
```

---

## 🚀 수정 방향

### Option 1: Pipeline.swift 확장 (추천)
```swift
// 기존 Pipeline을 2-wide로 확장
class SuperscalarPipeline {
    var ifid: [IFIDRegister] = []  // 2개 저장
    var idex: [IDEXRegister] = []  // 2개 저장
    var exmem: [EXMEMRegister] = []
    var memwb: [MEMWBRegister] = []
    
    func tick() {
        // 기존 Pipeline 로직 재사용
        // Width만 2로 증가
    }
}
```

### Option 2: CoreSuperscalar 완전 재작성
```swift
// 진짜 파이프라인 레지스터 구현
class CoreSuperscalar {
    // Pipeline registers
    var ifidRegisters: [IFIDRegister]
    var idexRegisters: [IDEXRegister]
    // ... 등등
    
    // 각 stage는 이전 stage의 레지스터에서 읽기만
    func fetchStage() {
        // Memory → ifidRegisters에 저장
    }
    
    func decodeStage() {
        // ifidRegisters 읽기 → idexRegisters에 저장
    }
}
```

---

## 📝 결론

### 현재 상황
```
❌ CoreSuperscalar: 파이프라인 구조 불완전
✅ Pipeline.swift: 제대로 된 5단 파이프라인 있음
```

### 해야 할 일
```
1. Pipeline.swift를 2-wide로 확장
   OR
2. CoreSuperscalar를 진짜 파이프라인으로 재작성

핵심: 슈퍼스칼라 = 파이프라인 필수!
```

---

*작성일: 2026-02-14*
*중요: 파이프라인 없는 슈퍼스칼라는 불가능합니다*
