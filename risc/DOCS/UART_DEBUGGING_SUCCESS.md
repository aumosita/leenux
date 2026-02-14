# UART 디버깅 성공 사례 연구

**날짜**: 2024  
**난이도**: ⭐⭐⭐⭐⭐ (매우 어려움)  
**소요 시간**: 약 3시간  
**결과**: ✅ 성공

---

## 📋 목차

1. [문제 개요](#문제-개요)
2. [초기 증상](#초기-증상)
3. [디버깅 과정](#디버깅-과정)
4. [근본 원인 분석](#근본-원인-분석)
5. [해결 방법](#해결-방법)
6. [교훈](#교훈)
7. [참고 자료](#참고-자료)

---

## 🎯 문제 개요

### 목표
UART 디바이스를 통한 "Hello, RISC-V!" 문자열 출력

### 증상
- `uart_simple.s`: 'H', 'i', '!', '\n' 출력 성공 ✅
- `uart_test.s`: '\n'만 출력되고 "Hello, RISC-V!"는 출력 안 됨 ❌

### 환경
- **아키텍처**: RISC-V 64I (5단계 파이프라인)
- **캐시**: L1 Cache 활성화
- **메모리**: 동기식 접근 (synchronous)
- **파이프라인**: WB → MEM → EX → ID → IF (역순 실행)

---

## 🔍 초기 증상

### 테스트 코드 비교

**작동하는 코드** (`uart_simple.s`):
```assembly
lui x10, 0x10000        # UART base
addi x11, x0, 'H'       # 직접 값 대입
sb x11, 0(x10)          # 출력
```

**실패하는 코드** (`uart_test.s`):
```assembly
lui x10, 0x10000        # UART base
auipc x11, 0            # 메시지 주소
addi x11, x11, 40
print_loop:
    lbu x12, 0(x11)     # 메모리에서 로드 ← 문제!
    beq x12, x0, end    # NULL 체크
    sb x12, 0(x10)
    addi x11, x11, 1
    j print_loop
```

### 핵심 차이점
- `uart_simple.s`: **즉시값 사용** (레지스터 간 연산만)
- `uart_test.s`: **메모리 로드** 후 분기 (Load-Use Hazard 발생)

---

## 🐛 디버깅 과정

### Phase 1: 메시지 주소 검증 ✅

**가설**: 메시지 주소가 잘못 계산됨

**검증**:
```bash
hexdump -C Examples/uart_test.bin
# 00000000  37 05 00 10 97 05 00 00  93 85 85 02 03 c6 05 00
# ...
# 00000020  13 06 a0 00 23 00 c5 00  73 00 10 00 48 65 6c 6c  <- 'Hell' at 0x2C
# 00000030  6f 2c 20 52 49 53 43 2d  56 21                    <- 'o, RISC-V!'
```

**결과**: 
- 메시지는 `0x102C`에 정확히 위치 ✅
- `auipc x11, 0` + `addi x11, x11, 40` = `0x1004 + 40 = 0x102C` ✅

### Phase 2: 메모리 로드 검증 ✅

**디버그 출력**:
```
[DEBUG] LBU: addr=0x102C, val=72, rawData=72
```

**결과**: 메모리에서 'H' (72)를 정확히 읽음 ✅

### Phase 3: 파이프라인 타이밍 분석 🔴

**디버그 출력**:
```
Cycle 8: [DEBUG] LBU: addr=0x102C, val=72, rawData=72   ← 값 72 읽음
Cycle 9: PC=0x1014                                      ← beq 다시 실행
Cycle 10: PC=0x1024                                     ← beq taken! (end로 점프)
```

**문제 발견**: `beq x12, x0`가 **x12=0으로 평가**되어 잘못 분기!

### Phase 4: Load-Use Hazard 추적 🎯

**파이프라인 타이밍 분석**:

| Cycle | WB | MEM | EX | ID | IF |
|-------|-----|-----|-----|-----|-----|
| 7 | - | - | - | lbu | beq |
| 8 | - | - | lbu | **beq (stall!)** | - |
| 9 | - | lbu (read 72) | **beq (재실행?)** | - | - |
| 10 | lbu (x12=72) | - | beq (branch!) | - | - |

**예상 동작**:
- Cycle 8: Hazard 감지 → Stall 1 cycle
- Cycle 9: decode() 스킵, lbu WB 대기
- Cycle 10: beq decode, x12=72 읽기

**실제 동작**:
- Cycle 8: Hazard 감지 → **decode() 실행됨!** 🔴
- Cycle 9: beq execute, x12=0으로 평가 🔴

### Phase 5: Stall 로직 검증 🔍

**코드 분석**:
```swift
// tick() 함수
func tick() {
    writeBack()
    memoryAccess()
    
    let memStalled = state.isWaitingForMemory && ...
    
    if !memStalled {
        execute()  // ← stallCycles 체크 없음!
        decode()   // ← stallCycles 체크 없음!
    }
    
    fetch(...)     // ← fetch() 내부에만 stallCycles 체크
}
```

**fetch() 내부**:
```swift
if stallCycles > 0 {
    stallCycles -= 1
    return  // ← fetch만 스킵!
}
```

**문제 발견**: 
- `fetch()`만 stall을 체크하고 스킵
- `execute()`와 `decode()`는 **stall을 무시하고 실행**

---

## 💡 근본 원인 분석

### 버그의 본질

**Load-Use Hazard Detection**:
```swift
// decode() 내부
let hazardDetected = HazardDetectionUnit.detectLoadUseHazard(
    idExMemRead: pipeline.idEx.memRead,  // lbu: true
    idExRd: pipeline.idEx.rd,            // 12
    ifIdRs1: idEx.rs1,                   // 12
    ifIdRs2: idEx.rs2                    // 0
)
if hazardDetected {
    stallCycles = 1       // ← Stall 설정
    pipeline.stall()      // ← idEx 무효화
    pc -= 4               // ← PC 롤백
    return                // ← 현재 cycle decode 중단
}
```

**문제**:
1. Cycle N: Hazard 감지, `stallCycles = 1` 설정
2. Cycle N+1: `tick()` 실행
   - `fetch()`는 `stallCycles` 체크 → 스킵 ✅
   - `decode()`는 `stallCycles` 무시 → **실행!** 🔴
   - `execute()`도 실행 → 잘못된 operand 사용

### 타이밍 다이어그램

```
Cycle 7: decode() detects hazard
         └─ stallCycles = 1
         └─ pc -= 4
         └─ idEx.valid = false

Cycle 8: tick() starts
         ├─ fetch() checks stallCycles > 0 → skip ✅
         ├─ decode() RUNS (should skip!) 🔴
         │  └─ reads registers[12] = 0
         │  └─ sets idEx.rs1Value = 0
         └─ execute() skipped (idEx.valid = false from stall())

Cycle 9: tick() starts
         ├─ writeBack() writes x12 = 72
         ├─ decode() runs (stall expired)
         └─ execute() runs with operandA = 0 (from Cycle 8!)
```

### 왜 이런 버그가 발생했나?

**설계 의도**:
- Stall은 **파이프라인 전체를 멈춤**
- 새로운 명령어가 파이프라인에 진입하지 않음

**실제 구현**:
- `fetch()`만 멈춤
- `decode()`와 `execute()`는 계속 실행
- **일부 단계만 stall → 파이프라인 불일치**

---

## ✅ 해결 방법

### 수정 코드

```swift
// Sources/Core.swift - tick() 함수
func tick() {
    guard !halted else { return }
    
    cyclesExecuted += 1
    
    // 1. Write Back
    writeBack()
    
    // 2. Memory Access
    memoryAccess()
    
    let memStalled = state.isWaitingForMemory && 
                     state.waitingStage == .memoryAccess
    
    // 3. ✅ Stall 체크 추가
    if stallCycles > 0 {
        stallCycles -= 1
        stallsDetected += 1
        // Don't execute or decode during stall
    } else if !memStalled {
        execute()
        decode()
    } else {
        stallsDetected += 1
    }
    
    // 4. Fetch
    fetch(pipelineStalled: memStalled)
    
    // 5. x0 고정
    registers[0] = 0
    
    if debug {
        printDebugInfo()
    }
}
```

### 추가 수정: fetch() 내부 중복 제거

```swift
// fetch() 내부 - 중복된 stall 체크 제거
private func fetch(pipelineStalled: Bool = false) {
    // ... buffered result handling ...
    
    if state.isWaitingForMemory { ... }
    if pipelineStalled { return }
    
    // ❌ 제거: if stallCycles > 0 { ... }
    
    // Cache Check
    if let cache = l1Cache { ... }
}
```

### 디버그 출력 강화

```swift
// execute() 내부 - Branch 명령 디버그
if debug && idEx.branch {
    print("[DEBUG] execute() - Forwarding params: ...")
    print("[DEBUG] execute() - exMem: rd=\(...), regWrite=\(...)")
    print("[DEBUG] execute() - memWb: rd=\(...), regWrite=\(...)")
}

// memoryAccess() 내부 - Load 완료 디버그
if debug && exMem.memRead {
    print("[DEBUG] memoryAccess() - Setting memWb: rd=\(...), memData=\(...)")
}
```

---

## 🎉 결과

### 수정 후 파이프라인 타이밍

```
Cycle 7: lbu [ID], beq [IF]
         └─ Hazard detected, stallCycles = 1

Cycle 8: lbu [EX → MEM]
         ├─ stallCycles = 1 → stallCycles = 0
         ├─ decode() SKIPPED ✅
         └─ execute() SKIPPED ✅

Cycle 9: lbu [MEM → WB]
         ├─ writeBack() writes x12 = 72 ✅
         ├─ decode() runs
         │  └─ reads registers[12] = 72 ✅
         └─ sets idEx.rs1Value = 72 ✅

Cycle 10: beq [ID → EX]
         └─ operandA = 72 (from idEx) ✅
         └─ branch NOT taken ✅

Cycle 11: sb [EX]
         └─ UART TX: 72 ('H') ✅
```

### 실제 출력

```bash
$ swift run risc-emulator Examples/uart_test.bin --debug
...
[DEBUG] LBU: addr=0x102C, val=72, rawData=72
[DEBUG] memoryAccess() - Setting memWb: rd=12, memData=72, regWrite=true
[Core 0] Cycle 9: PC=0x1014, Instr=3
[DEBUG] WB: rd=12, memToReg=true, memData=72
[DEBUG] execute() - Forwarding params: idEx.rs1=12, idEx.rs2=0
[DEBUG] Branch: op=beq, a=72, b=0, taken=false ✅
[UART TX: 72]
H  ✅
```

---

## 📚 교훈

### 1. 파이프라인 Stall은 일관성 있게 적용

**원칙**: Stall은 **모든 파이프라인 단계**에 영향을 미쳐야 함

**잘못된 구현**:
```
IF: stall 체크 ✅
ID: stall 무시 🔴
EX: stall 무시 🔴
```

**올바른 구현**:
```
tick() 레벨에서 stall 체크
├─ IF: skip
├─ ID: skip
└─ EX: skip
```

### 2. 파이프라인 레지스터 상태 추적의 중요성

**핵심 디버그 정보**:
```swift
print("pipeline.idEx: rd=\(...), rs1=\(...), rs1Value=\(...), valid=\(...)")
print("pipeline.exMem: rd=\(...), regWrite=\(...), valid=\(...)")
print("pipeline.memWb: rd=\(...), memData=\(...), regWrite=\(...), valid=\(...)")
```

각 사이클마다 파이프라인 레지스터 상태를 추적해야 타이밍 버그 발견 가능

### 3. Load-Use Hazard의 미묘함

**단순한 Forwarding으로는 부족**:
- Forwarding: EX/MEM → EX, MEM/WB → EX
- Load-Use: **값이 MEM 단계에서 준비됨** → 1 cycle stall 필요

**Stall + Forwarding 조합 필요**:
```
Cycle N:   Load (MEM)
Cycle N+1: Use (stall)     ← 1 cycle 대기
Cycle N+2: Use (EX)        ← Forwarding 가능
```

### 4. 디버그 출력의 타이밍

**주의**: 디버그 출력 위치가 실제 실행 순서를 반영해야 함

```swift
func tick() {
    writeBack()     // 출력: [DEBUG] WB: ...
    memoryAccess()  // 출력: [DEBUG] MEM: ...
    execute()       // 출력: [DEBUG] EX: ...
    decode()        // 출력: [DEBUG] ID: ...
    fetch()         // 출력: [DEBUG] IF: ...
    
    printDebugInfo() // 출력: [Core X] Cycle Y: ...
}
```

출력 순서: WB → MEM → EX → ID → IF → Cycle 번호

### 5. 구조화된 디버깅 프로세스

```
1. 증상 확인 (무엇이 잘못되었나?)
   └─ 출력: '\n'만 나옴

2. 가설 수립 (왜 그럴까?)
   ├─ 메시지 주소 문제? → 검증: hexdump
   ├─ 메모리 로드 문제? → 검증: LBU 디버그
   └─ 파이프라인 문제? → 검증: 타이밍 추적 ✅

3. 근본 원인 파악
   └─ Stall 로직 불완전

4. 수정 및 검증
   └─ tick() 수정 → 'H' 출력 성공!
```

---

## 🔧 남은 이슈

### 1. uart_test.s 루프 문제

**증상**: 첫 글자 'H'만 출력되고 PC가 `0x20100C`로 점프

**원인 추정**: 
- `j print_loop` 명령의 immediate 계산 오류?
- 어셈블러 버그?

**바이너리 분석**:
```
0x101C: 6f f0 1f ff  # j print_loop
```

**다음 단계**: J-type 명령어 디코딩 검증 필요

### 2. UART 출력 버퍼링

**현재**: 개별 문자마다 즉시 출력  
**개선**: 개행 문자까지 버퍼링 후 한 번에 출력

### 3. 테스트 자동화

**필요**: 
- UART 출력 캡처 메커니즘
- 예상 출력과 비교
- IntegrationTests에 추가

---

## 📊 통계

### 디버깅 세션
- **소요 시간**: ~3시간
- **코드 수정**: 2개 함수 (tick, fetch)
- **디버그 출력 추가**: 5곳
- **테스트 실행**: 20+ 회

### 파이프라인 사이클 분석
- **문제 발생 사이클**: Cycle 8-10
- **핵심 사이클**: Cycle 8 (decode 잘못 실행)
- **수정 후 추가 사이클**: +1 (stall로 인한)

### 코드 변경
```
tick():        +5 lines (stall 체크)
fetch():       -3 lines (중복 제거)
execute():     +5 lines (디버그)
memoryAccess(): +3 lines (디버그)
```

---

## 🎓 참고 자료

### RISC-V 사양
- [RISC-V Unprivileged ISA Specification](https://riscv.org/technical/specifications/)
- [RISC-V Pipelined Processors](https://inst.eecs.berkeley.edu/~cs61c/)

### 파이프라인 Hazards
- **Data Hazard**: RAW (Read After Write)
- **Structural Hazard**: 리소스 충돌
- **Control Hazard**: Branch misprediction

### 해결 기법
- **Forwarding (Bypassing)**: EX/MEM, MEM/WB → EX
- **Stalling**: Pipeline bubble 삽입
- **Branch Prediction**: Dynamic prediction

### 관련 파일
- `Sources/Core.swift`: 코어 파이프라인 구현
- `Sources/Pipeline.swift`: 파이프라인 레지스터 정의
- `UART_DEBUG_LOG.md`: 전체 디버깅 로그
- `PROJECT_ROADMAP.md`: Day 6-7

---

## 🏆 결론

**성공 요인**:
1. ✅ 체계적인 디버깅 프로세스
2. ✅ 상세한 디버그 출력
3. ✅ Cycle-by-cycle 분석
4. ✅ 가설 수립 및 검증

**핵심 교훈**:
> "파이프라인 버그는 **타이밍**의 문제이다. 각 사이클의 각 단계에서 무슨 일이 일어나는지 정확히 추적해야만 찾을 수 있다."

**다음 단계**:
- J-type 명령어 디코딩 검증
- 전체 문자열 출력 테스트
- UART 기능 테스트 자동화

---

**작성자**: AI Assistant  
**검토자**: -  
**버전**: 1.0  
**마지막 업데이트**: 2024
