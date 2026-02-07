# UART 테스트 디버그 세션

## 날짜: 2024
## 목표: uart_test.s 루프 검증 (j 명령어) 및 전체 문자열 출력 테스트

---

## 테스트 파일: Examples/uart_test.s

```assembly
# UART 테스트 프로그램
# "Hello, RISC-V!" 출력

.section .text
.globl _start

_start:
    # UART 베이스 주소
    lui x10, 0x10000        # x10 = 0x10000000 (UART base)
    
    # 메시지 주소 준비
    auipc x11, 0            # x11 = PC (이 명령어 주소: 0x1004)
    addi x11, x11, 40       # x11 = 0x1004 + 40 = 0x102C (message 위치)
    
print_loop:
    # 문자 로드
    lbu x12, 0(x11)         # x12 = *x11 (현재 문자)
    
    # NULL 체크
    beq x12, x0, end        # if (x12 == 0) goto end
    
    # UART TX로 문자 출력
    sb x12, 0(x10)          # *0x10000000 = x12
    
    # 다음 문자로
    addi x11, x11, 1        # x11++
    j print_loop
    
end:
    # 줄바꿈 출력
    addi x12, x0, 10        # x12 = '\n'
    sb x12, 0(x10)
    
    # 프로그램 종료
    ebreak

# 데이터를 코드 섹션에 포함
message:
    .byte 'H', 'e', 'l', 'l', 'o', ',', ' '
    .byte 'R', 'I', 'S', 'C', '-', 'V', '!', 0
```

---

## 실행 결과

### 어셈블 및 실행
```bash
cd Examples
python3 ../Tools/simple_assembler.py uart_test.s uart_test.bin
swift run risc-emulator uart_test.bin
```

### 출력 결과
```
✅ 성공: "Hello, RISC-V!" 문자열 출력됨
❌ 문제: NULL(0) 이후에도 계속 0을 출력하며 무한 루프
```

### 실제 출력
```
Hello, RISC-V!
(0을 무한히 출력 - 최대 사이클 도달까지)
```

### 최종 상태
```
Core 0 Status:
  PC: 0x1020
  Cycles: 10000
  Instructions: 5713
  CPI: 1.75
  x10 (a0) = 268435456  (0x10000000 - UART 주소)
  x11 (a1) = 5567       (!!!! 문자열 포인터가 계속 증가)
  Halted: false
```

---

## 바이너리 분석

### 디스어셈블된 명령어
```
0x1000: 0x10000537  lui x10, 0x10000
0x1004: 0x00000597  auipc x11, 0
0x1008: 0x02858593  addi x11, x11, 40
0x100C: 0x0005C603  lbu x12, 0(x11)      <- print_loop
0x1010: 0x00060863  beq x12, x0, end     <- NULL 체크
0x1014: 0x00C50023  sb x12, 0(x10)
0x1018: 0x00158593  addi x11, x11, 1
0x101C: 0xFF1FF06F  j print_loop         <- j 명령어 (offset: -16)
0x1020: 0x00A00613  addi x12, x0, 10     <- end 레이블
0x1024: 0x00C50023  sb x12, 0(x10)
0x1028: 0x00100073  ebreak
0x102C: "Hello, RISC-V!\0"
```

---

## 개별 명령어 테스트

### 1. J 명령어 테스트

**파일:** `Examples/j_test.s`
```assembly
_start:
    addi x10, x0, 1       # x10 = 1
    j skip                # 점프
    addi x10, x0, 99      # 실행되면 안 됨
skip:
    addi x11, x0, 2       # x11 = 2
    ebreak
```

**결과:** ✅ **정상 작동**
```
x10 (a0) = 1
x11 (a1) = 2
```

### 2. BEQ 명령어 테스트

**파일:** `Examples/beq_test.s`
```assembly
_start:
    addi x10, x0, 0       # x10 = 0
    addi x11, x0, 0       # x11 = 0
    beq x10, x11, equal   # 같으면 equal로
    addi x12, x0, 99      # 실행되면 안 됨
equal:
    addi x12, x0, 42      # x12 = 42
    ebreak
```

**결과:** ✅ **정상 작동**
```
x12 (a2) = 42
```

---

## 문제 분석

### 증상
1. ✅ "Hello, RISC-V!" 문자열이 정상적으로 출력됨
2. ✅ lbu, sb, addi 명령어 정상 작동
3. ❌ **NULL(0)을 만난 후에도 beq가 end로 점프하지 않음**
4. ❌ x11이 5567까지 증가 (문자열 포인터가 계속 증가)
5. ❌ 메모리에서 0을 계속 읽어서 출력

### 가설

#### 가설 1: beq가 작동하지 않는다
- ❌ **기각**: beq_test.s에서 beq는 정상 작동

#### 가설 2: lbu가 0을 제대로 로드하지 못한다
- 검증 필요: lbu가 NULL(0)을 x12에 제대로 로드하는가?

#### 가설 3: Forwarding 문제
- beq에서 비교할 때 x12의 값이 forwarding되지 않는가?
- 디버그 로그: `[DEBUG] decodeBType: rs1=18, rs2=22, rs1Value=0, rs2Value=0`
  - rs1=18 (x18)
  - rs2=22 (x22)
  - ⚠️ **x12는 레지스터 12번인데 rs1=18, rs2=22?**

#### 가설 4: 어셈블러 버그
- beq의 레지스터 번호가 잘못 인코딩되었을 가능성
- 검증: 바이너리 `0x00060863` 디코딩

### beq 명령어 디코딩 (0x00060863)

```
0000 0000 0000 0110 0000 1000 0110 0011
```

B-Type 포맷:
```
imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
[31:25]      [24:20][19:15][14:12]  [11:7]        [6:0]
```

디코딩:
```
imm[12|10:5] = 0000000 (bits 31-25)
rs2          = 00000   (bits 24-20) = x0 ✅
rs1          = 01100   (bits 19-15) = 12 = x12 ✅
funct3       = 000     (bits 14-12) = BEQ ✅
imm[4:1|11]  = 10000   (bits 11-7)
opcode       = 1100011 (bits 6-0)  = BRANCH ✅
```

immediate 계산:
```
imm[12:1] = [0|0000|0|1000] = 0000 0000 1000 (binary) = 16 (decimal) ✅
```

**어셈블러는 정상!** beq x12, x0, +16 (end로 점프)

---

## 🔍 핵심 문제 발견

디버그 로그를 확인한 결과:
```
[DEBUG] decodeBType: rs1=18, rs2=22, rs1Value=0, rs2Value=0
```

**rs1=18, rs2=22로 디코딩되고 있음!**

예상: rs1=12 (x12), rs2=0 (x0)
실제: rs1=18 (x18), rs2=22 (x22)

이는 **어셈블러 문제가 아니라 에뮬레이터의 디코딩 문제**입니다!

---

## 다음 단계

1. ✅ Instruction.swift의 B-Type 디코딩 확인
2. ✅ beq 디코딩 시 rs1, rs2 레지스터 번호 추출 로직 검증 - **정상**
3. ✅ 실제 바이너리 `0x00060863`의 디코딩 결과 확인 - **rs1=12, rs2=0 정상**
4. ⏳ 더 간단한 테스트로 문제 범위 좁히기

---

## 예상 원인

B-Type 명령어의 비트 필드 추출에서:
- rs1 비트 위치: [19:15]
- rs2 비트 위치: [24:20]

**검증 결과:** ✅ 디코더는 정상 작동

---

## 추가 테스트: uart_simple_test.s

더 단순한 테스트로 문제 범위를 좁히기 위해 작성:
```assembly
_start:
    lui x10, 0x10000        # UART 주소
    
    addi x11, x0, 65        # 'A'
    sb x11, 0(x10)
    
    addi x11, x0, 66        # 'B'
    sb x11, 0(x10)
    
    addi x11, x0, 67        # 'C'
    sb x11, 0(x10)
    
    addi x12, x0, 0         # x12 = 0
    beq x12, x0, done       # NULL 체크
    
    addi x11, x0, 88        # 'X' (실행되면 안 됨)
    sb x11, 0(x10)
    
done:
    ebreak
```

**결과:**
```
B  <- 'A'가 출력 안 됨!
C
x11 = 67
```

**새로운 발견:** 
- ❌ 첫 번째 출력 'A'(65)가 누락됨
- ✅ 'B'(66), 'C'(67)는 정상 출력
- ❌ beq가 작동하지 않음 (done으로 점프하지 않고 ebreak 실행)
- ✅ x11 = 67 (마지막 값 유지)

**이는 파이프라인 또는 첫 명령어 실행 문제를 시사합니다.**

---

## 상세 디버깅 세션

### 디버그 로그 분석 (uart_simple_test.bin)

#### 실행 순서
```
Cycle 1-6: 파이프라인 초기화
Cycle 7: WB x10 = 268435456 (UART 주소)
Cycle 8: WB x11 = 65 ('A')    ← 레지스터에 쓰기 완료
Cycle 9: sb 실행되어야 함    ← **실행 안 됨!**
Cycle 10: WB x11 = 66 ('B')   
Cycle 11: sb 실행 (B 출력)    ✅
Cycle 12: WB x11 = 67 ('C')
Cycle 13: sb 실행 (C 출력)    ✅
Cycle 14: beq 실행
```

**발견:** 첫 번째 sb (0x1008) 명령어가 실행되지 않음!

---

## 🔍 Branch PC 계산 문제 발견 및 수정

### 문제 1: beq의 PC 계산 오류

#### 증상
```
0x1020: beq x12, x0, +12  (target: 0x102C)
실제 결과: PC = 0x1030  (예상보다 +4)
```

#### 원인
파이프라인 실행 순서:
```swift
tick() {
    writeBack()
    memoryAccess()
    execute()    // ← beq 실행, pc = branchTarget (0x102C)
    decode()
    fetch()      // ← PC += 4 실행 (0x102C → 0x1030)
}
```

**execute()에서 PC를 설정한 후, fetch()가 다시 PC += 4를 실행**하는 것이 문제!

#### 해결책

fetch()가 PC를 증가시키기 **전에** branchTarget을 설정하도록 -4 보정:

```swift
// 수정 전
if actualTaken {
    pc = branchTarget  // 0x102C
}
// fetch()가 PC += 4 실행 → 0x1030

// 수정 후
if actualTaken {
    pc = branchTarget &- 4  // 0x1028
}
// fetch()가 PC += 4 실행 → 0x102C ✅
```

### 수정 코드

**Sources/Core.swift - execute() 함수:**
```swift
// 예측 실패 시 파이프라인 플러시
if actualTaken != predicted {
    branchMispredictions += 1
    if actualTaken {
        // 예측: not taken, 실제: taken → 분기 타겟으로 점프
        // fetch가 PC를 +4 하기 전에 설정하도록 -4 보정
        pc = branchTarget &- 4
    } else {
        // 예측: taken, 실제: not taken → 순차적 실행
        pc = idEx.pc &+ 4 &- 4
    }
    pipeline.flush()
} else {
    // 예측 성공
    if actualTaken {
        // 예측도 taken, 실제도 taken → 분기 타겟으로 점프
        // fetch가 PC를 +4 하기 전에 설정하도록 -4 보정
        pc = branchTarget &- 4
    }
}
```

### 테스트 결과

#### 수정 후 uart_simple_test.bin 실행:
```bash
swift run risc-emulator Examples/uart_simple_test.bin
```

**결과:**
```
출력: B C C
Halted: true  ✅ (beq가 done으로 점프함)
Branches: 1 taken
```

**개선점:**
- ✅ beq가 정상적으로 done(0x102C)로 점프
- ✅ 프로그램이 ebreak에서 정상 종료

**남은 문제:**
- ❌ 'A'(65) 출력 누락
- ❌ 'C'(67) 중복 출력

---

## 문제 2: 첫 번째 sb 명령어 실행 누락

### 상세 분석

#### 바이너리 구조
```
0x1000: lui x10, 0x10000    (UART 주소)
0x1004: addi x11, x0, 65    ('A' 로드)
0x1008: sb x11, 0(x10)      ('A' 출력) ← 실행 안 됨!
0x100C: addi x11, x0, 66    ('B' 로드)
0x1010: sb x11, 0(x10)      ('B' 출력) ✅
0x1014: addi x11, x0, 67    ('C' 로드)
0x1018: sb x11, 0(x10)      ('C' 출력) ✅
0x101C: addi x12, x0, 0     (0 로드)
0x1020: beq x12, x0, +12    (done으로) ✅
0x1024: addi x11, x0, 88    ('X' - 실행 안 됨) ✅
0x1028: sb x11, 0(x10)      (실행 안 됨) ✅
0x102C: ebreak              (종료) ✅
```

#### Write Back 로그
```
Cycle 7: WB x10 = 268435456  (UART 주소) ✅
Cycle 8: WB x11 = 65         ('A' 레지스터 쓰기) ✅
Cycle 9: ???                 (sb 실행 예상) ❌
Cycle 10: WB x11 = 66        ('B' 레지스터 쓰기) ✅
Cycle 11: UART write (66)    ('B' 출력) ✅
Cycle 12: WB x11 = 67        ('C' 레지스터 쓰기) ✅
Cycle 13: UART write (67)    ('C' 출력) ✅
Cycle 14: UART write (67)    ('C' 중복 출력) ❌
```

#### UART 출력 상세
```
[UART write8: offset=0, value=66]  ← 'B'
[UART TX: 66]
B
[UART write8: offset=0, value=67]  ← 'C'
[UART TX: 67]
C
[UART write8: offset=0, value=67]  ← 'C' 중복
[UART TX: 67]
```

### 가설

#### 가설 1: 첫 번째 sb가 파이프라인에서 손실됨
- 파이프라인 flush나 stall 시 첫 번째 store가 무효화되었을 가능성
- Pipeline.swift의 flush()/stall() 로직 확인 필요

#### 가설 2: 명령어 카운트 문제
```
Instructions: 6
예상: 9 (lui, addi, sb, addi, sb, addi, sb, addi, beq)
```
실제로 실행된 명령어가 6개뿐 → **3개의 명령어가 실행 안 됨**

#### 가설 3: Store 명령어 처리 타이밍
- memoryAccess() 단계에서 store가 실행되는데
- 첫 번째 store만 유독 실행이 안 됨
- 파이프라인 초기화 문제일 가능성

---

## 통계 요약

### Memory Bus Statistics
```
Total requests: 5
Reads: 1    (명령어 fetch)
Writes: 4   (예상: 3, 실제: 4 - 중복 있음)
```

### L1 Cache Statistics  
```
Total accesses: 16
Hits: 15
Misses: 1
Hit rate: 93.75%
```

### Branch Statistics
```
Branches: 1 taken, 0 not taken
Branch mispredictions: 1
Accuracy: 0.00%
```

---

## 다음 디버깅 단계

1. ⏳ 파이프라인에서 첫 번째 sb 명령어가 어디서 손실되는지 추적
2. ⏳ Instruction counter가 왜 6개인지 확인 (9개 예상)
3. ⏳ 'C' 중복 출력 원인 파악
4. ⏳ memoryAccess() 단계의 store 처리 로직 검증
5. ⏳ 파이프라인 초기화 시 첫 명령어 처리 확인

---

## 현재 상태

### 해결됨 ✅
1. j 명령어 정상 작동 확인
2. beq 명령어 정상 작동 확인
3. beq PC 계산 오류 수정 (fetch의 PC+=4 보정)
4. 프로그램이 ebreak에서 정상 종료

### 미해결 ❌
1. 첫 번째 sb (0x1008) 실행 누락
2. 'A'(65) 출력 누락  
3. 'C'(67) 중복 출력
4. 명령어 카운트 불일치 (6 vs 9)

### 핵심 문제
**파이프라인에서 특정 명령어(첫 번째 store)가 실행되지 않는 버그**
