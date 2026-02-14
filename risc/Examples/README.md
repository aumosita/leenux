# Example Programs for RISC-V 64I Emulator

이 디렉토리에는 RISC-V 64I 에뮬레이터를 테스트하기 위한 예제 프로그램들이 있습니다.

## 예제 프로그램 목록

### 01_arithmetic.bin
**설명**: 기본 산술 연산 테스트
**테스트 명령어**: ADDI, ADD, SUB, AND, OR, XOR, SLL, SRL
**예상 결과**:
- x1 = 42
- x2 = 58
- x3 = 100 (x1 + x2)
- x4 = 16 (x2 - x1)
- x5 = 40 (x1 & x2)
- x6 = 60 (x1 | x2)
- x7 = 20 (x1 ^ x2)

### 02_memory.bin
**설명**: 메모리 로드/스토어 테스트
**테스트 명령어**: SD, LD, SW, LW, SH, LH, SB, LB
**예상 결과**:
- 메모리 주소 0x2000에 값 저장 및 로드
- 다양한 크기(8/16/32/64비트) 모두 테스트

### 03_branches.bin
**설명**: 분기 명령어 테스트
**테스트 명령어**: BEQ, BNE, BLT, BGE, BLTU, BGEU
**예상 결과**:
- 조건부 분기가 올바르게 실행됨
- x10 = 1 (모든 분기 테스트 통과)

### 04_function_call.bin
**설명**: 함수 호출 및 스택 사용 테스트
**테스트 명령어**: JAL, JALR, ADDI (스택 포인터 조작)
**예상 결과**:
- 함수 호출 및 반환 성공
- 스택 프레임 올바르게 관리됨
- x10 = 계산 결과

### 05_comprehensive.bin
**설명**: 모든 명령어 타입 종합 테스트
**테스트 명령어**: 위의 모든 명령어 조합
**예상 결과**:
- 모든 테스트 케이스 통과
- x31 = 0xDEADBEEF (성공 마커)

## 실행 방법

```bash
# 특정 예제 실행
swift run risc Examples/01_arithmetic.bin

# 또는 프로젝트 루트에서
swift build
.build/debug/risc Examples/01_arithmetic.bin
```

## 바이너리 재생성

예제 어셈블리 파일을 수정한 경우, 다음 명령으로 바이너리를 재생성할 수 있습니다:

```bash
# 모든 예제 재생성
cd Tools
./create_examples.sh

# 또는 개별 파일 어셈블
./assemble.sh ../Examples/01_arithmetic.s ../Examples/01_arithmetic.bin
```

## 주의사항

- 프로그램은 0x1000 주소에서 시작됩니다
- EBREAK (0x00100073) 명령으로 프로그램을 종료합니다
- 스택 포인터(sp/x2)는 0x10000으로 초기화됩니다
