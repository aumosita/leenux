# UART 디버깅 로그

**날짜**: 2024
**단계**: PROJECT_ROADMAP.md Day 6-7 마무리
**목표**: UART 디바이스를 통한 문자열 출력 기능 구현 및 테스트
**상태**: 파이프라인 타이밍 문제 디버깅 중

---

## 📊 현재 상태

### ✅ 완료된 항목

1. **UART 디바이스 구현** (`Sources/UARTDevice.swift`)
   - Thread-safe 구현 (NSLock 사용)
   - MMIO 프로토콜 준수
   - 레지스터 맵:
     - 0x00: TX Data (Write) - 문자 출력
     - 0x04: RX Data (Read) - 문자 입력
     - 0x08: Status (Read) - 상태 레지스터
   - 베이스 주소: 0x10000000

2. **MMIO 프레임워크** (`Sources/MMIODevice.swift`, `Sources/SharedMemory.swift`)
   - 디바이스 등록 및 라우팅 메커니즘
   - 메모리 맵 정의 완료
   - SharedMemory에서 MMIO 주소 범위 자동 감지

3. **통합 테스트 프레임워크** (`Tests/IntegrationTests/IntegrationTests.swift`)
   - 시스템 콜 테스트 (exit, spawn, yield)
   - 실행 가능 바이너리 자동 탐색

4. **어셈블러 개선** (`Tools/simple_assembler.py`)
   - ✅ `.byte` 지시어 구현 완료
   - 문자열 및 숫자 값 모두 지원
   - 예: `.byte 'H', 'e', 'l', 'l', 'o', 0`

5. **작동하는 테스트 프로그램**
   - `Examples/uart_simple.s` ✅
     - 'H', 'i', '!' + '\n' 출력
     - 직접 주소 지정 방식 사용
     - 정상 작동 확인

---

## 🔨 진행 중인 문제

### 문제 1: uart_test.bin 문자열 출력 실패

**증상**:
- "Hello, RISC-V!" 문자열을 출력해야 하지만 개행 문자('\n')만 출력됨
- uart_simple.bin은 정상 작동하지만 uart_test.bin은 실패

**원인 분석**:

1. **초기 문제: `.byte` 지시어 미지원**
   ```python
   # Tools/simple_assembler.py (수정 전)
   elif line.startswith('.byte'):
       # TODO: Implement byte.... 
       pass
   ```
   - **해결**: `.byte` 지시어 구현 완료 ✅
   - 문자열과 숫자 값 모두 파싱 가능

2. **`la` (load address) pseudo-instruction 미지원**
   ```assembly
   # uart_test.s (원본)
   la x11, message    # 어셈블러가 지원하지 않음!
   ```
   - `la`는 `auipc` + `addi`로 확장되어야 함
   - 현재 어셈블러는 이를 지원하지 않음
   - **임시 해결책**: `lui` + `addi` 또는 `auipc` + `addi` 직접 사용

3. **`.section .data` 처리 문제**
   ```assembly
   .section .text
   # ... 코드 ...
   
   .section .data    # 이 섹션이 무시됨!
   message:
       .byte 'H', 'e', 'l', 'l', 'o', 0
   ```
   - 어셈블러가 `.section` 지시어를 무시함
   - 데이터가 코드와 함께 순차적으로 배치됨
   - 메시지 주소를 하드코딩으로 계산해야 함

4. **메시지 주소 계산 문제**
   - 프로그램은 0x1000에 로드됨
   - 명령어들이 먼저 배치되고 그 뒤에 데이터 배치
   - 하드코딩된 주소 (0x1020, 0x1028, 0x102C 등) 시도했으나 실패
   - 명령어 추가/수정 시마다 메시지 위치가 변경됨

**현재 시도한 방법들**:

```assembly
# 방법 1: lui + addi (실패 - 12비트 immediate 제한)
addi x11, x0, 0x1028    # 0x1028은 12비트를 초과!

# 방법 2: lui + addi 조합 (주소 불일치)
lui x11, 0x1
addi x11, x11, 0x28     # 계산된 주소가 실제 메시지 위치와 다름

# 방법 3: auipc + addi (현재 시도 중)
auipc x11, 0            # x11 = PC
addi x11, x11, 48       # 오프셋 계산 필요
```

**디버그 출력**:
```
[Core 0] Cycle 10: PC=0x1010, Instr=3
[Core 0] Cycle 11: PC=0x1014, Instr=3
[Core 0] Cycle 12: PC=0x1024, Instr=4
[UART write8: offset=0, value=10]  # '\n'만 출력됨
```

- BEQ가 즉시 taken되어 end로 점프
- x12 (lbu로 읽은 문자) = 0 또는 10
- x11 (메시지 주소)가 잘못된 위치를 가리킴

---

## 🔍 심층 디버깅 분석 (2024 업데이트)

### 1. 메시지 주소 계산 ✅ 해결

```bash
hexdump -C Examples/uart_test.bin
```

**결과**:
```
00000000  37 05 00 10 97 05 00 00  93 85 85 02 03 c6 05 00
00000010  63 08 06 00 23 00 c5 00  93 85 15 00 6f f0 1f ff
00000020  13 06 a0 00 23 00 c5 00  73 00 10 00 48 65 6c 6c  <- 'Hell' 시작
00000030  6f 2c 20 52 49 53 43 2d  56 21                    <- 'o, RISC-V!'
```

- **메시지 오프셋**: `0x2C` (바이너리 내)
- **메모리 주소**: `0x1000 + 0x2C = 0x102C`
- **auipc 위치**: `0x1004` (PC)
- **필요한 오프셋**: `0x102C - 0x1004 = 40`
- **uart_test.s 수정**: `addi x11, x11, 40` ✅

### 2. 메모리 로드 확인 ✅

```
📂 Program loaded at 0x1000 (58 bytes)
   Memory verification at 0x1000:
   37 05 00 10 97 05 00 00 93 85 85 02 03 C6 05 00 
   63 08 06 00 23 00 C5 00 93 85 15 00 6F F0 1F FF 
   13 06 A0 00 23 00 C5 00 73 00 10 00 48 65 6C 6C  <- 'H' at 0x102C ✅
   6F 2C 20 52 49 53 43 2D 56 21 
```

### 3. LBU 명령어 확인 ✅

**디버그 출력**:
```
[DEBUG] LBU: addr=0x102C, val=72, rawData=72
```
- 메모리에서 **'H' (72)를 정확히 읽음!**
- 주소 계산 정확

### 4. Load-Use Hazard Detection ✅

```
[DEBUG] Hazard check: idEx.memRead=true, idEx.rd=12, rs1=12, rs2=0, hazard=true
```
- Hazard 감지 정상 작동
- `lbu x12`와 `beq x12, x0` 사이의 의존성 감지됨
- Stall 발생 (PC 롤백)

### 5. ❌ 파이프라인 타이밍 문제 발견

**현상**:
```
Cycle 8: [DEBUG] LBU: addr=0x102C, val=72, rawData=72   <- 값 72 읽음
Cycle 9: PC=0x1014                                      <- beq 다시 실행
Cycle 10: PC=0x1024                                     <- beq taken! (end로 점프)
```

**문제 분석**:

| Cycle | WB | MEM | EX | ID |
|-------|-----|-----|-----|-----|
| 8 | 이전 명령 | lbu→memWb.memData=72 | beq(x12=0?) | - |
| 9 | lbu→x12=72 | - | - | beq decode |
| 10 | - | - | beq EX | - |

**근본 원인**:
1. `beq`가 EX 단계에서 분기 결정을 내림
2. `decode()` 시점에 `registers[12]`을 읽어서 `idEx.rs1Value`에 저장
3. Stall 후에도 Forwarding이 제대로 적용되지 않음
4. `tick()` 실행 순서: WB → MEM → EX → ID → IF (역순)

**예상 vs 실제**:
- 예상: Cycle 9에서 `beq` decode 시 x12 = 72 (이미 WB 완료)
- 실제: `beq`가 x12 = 0으로 평가되어 branch taken

---

## 💡 해결 방안

### 즉시 해결 필요 (Pipeline Timing Bug)

**문제**: Load-Use Hazard 후 Forwarding 실패

**수정 필요 위치**: `Sources/Core.swift`

**옵션 1: decode()에서 레지스터 읽기 시점 수정**
```swift
// 현재: decode() 시작 시 레지스터 읽기
idEx.rs1Value = registers[Int(rs1)]  // 이 시점에 x12 = 0

// 필요: execute() 시점에서 Forwarding 후 최종 값 사용
```

**옵션 2: Branch 분기 결정을 MEM 단계로 이동**
- 더 많은 stall 발생하지만 정확성 보장

**옵션 3: MEM-to-EX Forwarding 개선**
```swift
// execute()에서 forwarding 적용 시:
case .memWb: 
    operandA = pipeline.memWb.memToReg ? pipeline.memWb.memData : pipeline.memWb.aluResult
// 현재 로직은 맞지만, 타이밍 문제 확인 필요
```

### 단기 해결책 ✅ 완료

1. **메시지 주소 계산** ✅
   - hexdump로 바이너리 확인
   - `auipc x11, 0` + `addi x11, x11, 40` 으로 수정
   - 메모리에서 정확히 읽힘 확인

2. **동기 메모리 접근으로 변경** ✅
   - `memoryAccess()`에서 async 대신 sync 사용
   - `memoryBus.read8()` 등 동기 API 사용

### 중기 해결책

1. **파이프라인 타이밍 버그 수정**
   - Load-Use stall 후 Forwarding 검증
   - `execute()`에서 branch operand 확인
   - 디버그 출력 추가하여 추적

2. **어셈블러 개선**
   - `la` pseudo-instruction 추가
   - 레이블 주소 자동 계산

### 장기 해결책

1. **파이프라인 리팩토링**
   - Hazard/Forwarding 로직 재검토
   - 더 정교한 cycle-accurate 시뮬레이션

2. **테스트 자동화**
   - UART 출력 검증 테스트
   - 파이프라인 타이밍 테스트

---

## 📋 작업 체크리스트

### Day 6-7 완료 조건

- [x] UARTDevice 구현
- [x] MMIO 프레임워크
- [x] 간단한 문자 출력 (uart_simple.s) ✅
- [ ] 문자열 출력 (uart_test.s) ⚠️ 진행 중
- [ ] 통합 테스트 작성
- [ ] 문서화

### 즉시 해결할 사항 (우선순위 순)

1. **uart_test.s 메시지 주소 계산 정확히 하기**
   - hexdump로 실제 메시지 위치 확인
   - auipc + addi 오프셋 재계산
   - 테스트 및 검증

2. **어셈블러 `.byte` 테스트**
   - 다양한 형식 테스트
   - 문자열, 숫자, 혼합

3. **UART 출력 검증 메커니즘**
   - outputCallback 구현
   - 테스트에서 출력 캡처
   - 예상 출력과 비교

---

## 🐛 알려진 버그

1. **uart_test_simple.s: 첫 번째 0 출력**
   - 원인 불명
   - 'H' 출력 전에 NULL 문자 출력됨
   - UARTDevice 또는 파이프라인 문제 가능성

2. **UART 디버그 출력**
   ```
   [UART write8: offset=0, value=105]
   [UART TX: 105]
   i
   ```
   - 디버그 로그가 실제 출력과 섞임
   - 가독성 저하

---

## 🔧 코드 변경 사항

### 1. `Sources/Core.swift` - 동기 메모리 접근

**변경 이유**: Async 메모리 접근이 파이프라인 타이밍과 충돌

**변경 내용**:
```swift
// 이전 (Async)
memoryBus.sendRequest(MemoryRequest(...))
state.isWaitingForMemory = true

// 이후 (Sync)
if let val = memoryBus.read8(coreId: id, address: address) {
    rawData = exMem.memSigned ? UInt64(Int64(Int8(bitPattern: val))) : UInt64(val)
}
```

### 2. `Examples/uart_test.s` - 주소 오프셋 수정

**변경 이전**:
```assembly
auipc x11, 0            # x11 = PC
addi x11, x11, 48       # 잘못된 오프셋
```

**변경 이후**:
```assembly
auipc x11, 0            # x11 = PC (0x1004)
addi x11, x11, 40       # x11 = 0x102C (정확한 메시지 위치)
```

### 3. 디버그 출력 추가

- `[DEBUG] LBU: addr=..., val=..., rawData=...`
- `[DEBUG] Hazard check: idEx.memRead=..., hazard=...`
- `[DEBUG] Branch: op=..., a=..., b=...`

---

## 📝 참고 사항

### 파이프라인 타이밍 이해

**tick() 실행 순서** (역순):
```
writeBack()      // 1. 이전 사이클 MEM/WB → 레지스터
memoryAccess()   // 2. EX/MEM → MEM/WB
execute()        // 3. ID/EX → EX/MEM (분기 결정!)
decode()         // 4. IF/ID → ID/EX (레지스터 읽기!)
fetch()          // 5. Memory → IF/ID
```

**Load-Use Hazard 타이밍**:
```
Cycle N:   lbu x12, 0(x11)   [ID]  ← memRead=true, rd=12
Cycle N+1: lbu                [EX]  ← Hazard 감지, beq stall
           beq x12, x0, end  [ID]  ← rs1=12 == rd=12 → STALL!
Cycle N+2: lbu                [MEM] ← 메모리 읽기, memWb.memData=72
Cycle N+3: lbu                [WB]  ← x12 = 72
           beq                [ID]  ← 다시 decode, registers[12] = 72?
Cycle N+4: beq                [EX]  ← 분기 결정
```

### RISC-V 주소 지정 방식

1. **절대 주소 (lui + addi)**
   ```assembly
   lui  x10, 0x10000      # x10 = 0x10000000
   addi x10, x10, 0x123   # x10 = 0x10000123
   ```

2. **PC-상대 주소 (auipc + addi)**
   ```assembly
   auipc x10, 0           # x10 = PC
   addi  x10, x10, 100    # x10 = PC + 100
   ```

### 메모리 맵

```
0x0000_0000 - 0x007F_FFFF : RAM (8MB)
0x1000_0000 - 0x1000_0FFF : UART
0x1000_1000 - 0x1000_1FFF : Timer
0x1000_3000 - 0x13FF_FFFF : Framebuffer
0x1400_0000 - 0x1400_0FFF : Keyboard

프로그램 로드 주소: 0x1000
```

---

## 🔄 다음 단계




### 즉시 해결 필요





1. **Branch operand 값 확인** ← 현재 진행 중
   - `execute()`에 디버그 추가: `operandA`, `operandB` 값 확인
   - 왜 `beq`가 taken으로 평가되는지 확인





2. **Forwarding 로직 검증**
   - `memWb` → `execute()` 포워딩 확인
   - `memWb.memToReg`, `memWb.memData` 값 확인





3. **Register Write 타이밍 확인**
   - `writeBack()`에서 x12에 72가 쓰이는 시점
   - `decode()`에서 x12를 읽는 시점

### 단기 목표

1. **uart_test.s "Hello, RISC-V!" 출력 성공**
2. **파이프라인 타이밍 버그 수정**
3. **Day 6-7 완료**

### 장기 목표

1. **어셈블러 `la` pseudo-instruction 추가**
2. **UART 통합 테스트 작성**
3. **Day 8-10: 시스템 콜 확장**

---




## 📊 디버그 명령어

```bash
# 어셈블 및 테스트
python3 Tools/simple_assembler.py Examples/uart_test.s Examples/uart_test.bin
swift run risc-emulator Examples/uart_test.bin --debug

# 바이너리 확인
hexdump -C Examples/uart_test.bin

# 메모리 확인 (시뮬레이터 내부)
dumpMemory(start: 0x1000, length: 64)
```

---

**마지막 업데이트**: 2024
**상태**: 🔨 파이프라인 타이밍 디버깅 중
**현재 문제**: Branch 분기 결정 시 operand 값이 0으로 평가됨
**다음 작업**: `execute()`에서 operandA/B 값 디버그 확인


## ✅ **버그 수정 성공!** (2026-02-07)

### 최종 해결책

**문제**: `tick()` 내부에서 stall 체크가 `fetch()`에만 있고, `execute()`와 `decode()`는 스킵하지 않았음!

**수정 결과**: 
- 'H' 출력 성공! 🎉
- Load-Use Hazard 후 포워딩 작동 확인

**핵심 수정**:
```swift
// tick() 함수 수정
if stallCycles > 0 {
    stallCycles -= 1
    // Don't execute or decode during stall
} else if !memStalled {
     execute()
     decode()
}
```

**다음 작업**: uart_test.s 루프 문제 해결 (j 명령어 검증)

