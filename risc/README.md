# RISC-V Emulator & OS Development Platform

**교육용 RISC-V 64비트 에뮬레이터 및 OS 개발 플랫폼**

---

## 🎯 프로젝트 개요

이 프로젝트는 RISC-V 아키텍처 기반의 운영체제를 개발하기 위한 **완전한 에뮬레이터 플랫폼**입니다.  
교육용으로 설계되었으며, OS의 핵심 개념을 학습하고 구현할 수 있습니다.

### Phase 1 완료: 에뮬레이터 ✅

현재 **Phase 1 (에뮬레이터)**이 완료되었으며, 모든 기능이 검증되었습니다.  
**Phase 2 (OS 개발)**를 위한 준비가 완료되었습니다.

---

## 🚀 빠른 시작

### 설치

```bash
# 릴리즈 바이너리 다운로드 (권장)
cd release
./risc-emulator Examples/uart_test.bin
```

또는 소스에서 빌드:

```bash
swift build -c release
.build/release/risc-emulator Examples/uart_test.bin
```

### 첫 프로그램 실행

```bash
# "Hello, RISC-V!" 출력
./risc-emulator Examples/uart_test.bin

# 산술 연산 테스트
./risc-emulator Examples/01_arithmetic.bin

# 디버그 모드로 실행
./risc-emulator Examples/01_arithmetic.bin --debug
```

---

## 📦 에뮬레이터 사양

### 지원 ISA
- ✅ **RV64I**: 기본 정수 명령어 세트
- ✅ **RV64M**: 곱셈/나눗셈 확장
- ✅ **RV64A**: Atomic 연산 (부분 지원)
- ✅ **RV64F/D**: 부동소수점 (부분 지원)

### 실행 모델
- **순차 실행** (Sequential Execution)
- **CPI = 1.0** (명령어당 1사이클)
- 간단하고 예측 가능한 동작
- 디버깅 용이

### 메모리 & I/O
- **메모리**: 8MB (기본), 설정 가능
- **MMIO 디바이스**:
  - 🖥️ **UART** (0x10000000): 직렬 통신
  - ⏰ **Timer** (0x10001000): 타이머
  - 🎨 **Framebuffer** (0x10003000): 1024x768 디스플레이
  - ⌨️ **Keyboard** (0x14000000): 키보드 입력

### 멀티코어
- 최대 8코어 지원
- 공유 메모리 아키텍처
- 순차 실행 (병렬 실행 옵션)

---

## 🎮 사용법

### 기본 실행

```bash
./risc-emulator <program.bin>
```

### 옵션

```bash
# 디버그 모드
./risc-emulator program.bin --debug

# 최대 사이클 제한
./risc-emulator program.bin --max-cycles 10000

# 메모리 크기 설정 (MB 단위)
./risc-emulator program.bin --memory 64

# 멀티코어 실행
./risc-emulator program.bin --cores 4

# 병렬 실행 (호스트 CPU 활용)
./risc-emulator program.bin --cores 4 --parallel

# 도움말
./risc-emulator --help
```

---

## 📚 지원 명령어

### 산술 & 논리 연산
```
ADD, SUB, ADDI
AND, OR, XOR, ANDI, ORI, XORI
SLL, SRL, SRA, SLLI, SRLI, SRAI
SLT, SLTU, SLTI, SLTIU
LUI, AUIPC
```

### M Extension (곱셈/나눗셈)
```
MUL, MULH, MULHSU, MULHU
DIV, DIVU, REM, REMU
```

### 메모리 연산
```
LB, LH, LW, LD, LBU, LHU, LWU
SB, SH, SW, SD
```

### 분기 & 점프
```
BEQ, BNE, BLT, BGE, BLTU, BGEU
JAL, JALR
```

### 시스템
```
EBREAK  - 프로그램 종료
ECALL   - 시스템 호출
```

---

## 🧪 테스트 프로그램

### 기본 테스트
| 파일 | 설명 | 검증 |
|------|------|------|
| `01_arithmetic.bin` | 산술 연산 | ✅ |
| `02_memory.bin` | Load/Store | ✅ |
| `03_branches.bin` | 분기 명령어 | ✅ |
| `04_function_call.bin` | 함수 호출 | ✅ |
| `05_comprehensive.bin` | 종합 테스트 | ✅ |

### M Extension 테스트
| 파일 | 설명 | 검증 |
|------|------|------|
| `06_m_extension_factorial.bin` | 팩토리얼 | ✅ |
| `07_m_extension_division.bin` | 나눗셈 | ✅ |
| `08_m_extension_gcd.bin` | GCD | ✅ |
| `09_m_extension_simple.bin` | 간단한 M 확장 | ✅ |

### 제어 흐름 테스트
| 파일 | 설명 | 검증 |
|------|------|------|
| `11_branch_loop.bin` | 루프 (20회) | ✅ |
| `uart_test.bin` | UART 출력 | ✅ |

**모든 테스트 통과! 🎉**

---

## 🛠️ 프로그램 작성

### Python 어셈블러 사용

```bash
python3 Tools/simple_assembler.py input.s output.bin
./risc-emulator output.bin
```

### 어셈블리 예제

```assembly
# hello.s - UART로 "Hi" 출력
.section .text
.globl _start

_start:
    lui x10, 0x10000        # UART 주소 (0x10000000)
    
    addi x11, x0, 72        # 'H'
    sb x11, 0(x10)
    
    addi x11, x0, 105       # 'i'
    sb x11, 0(x10)
    
    addi x11, x0, 10        # '\n'
    sb x11, 0(x10)
    
    ebreak                  # 종료
```

### 컴파일 및 실행

```bash
python3 Tools/simple_assembler.py hello.s hello.bin
./risc-emulator hello.bin
```

---

## 📊 성능 통계

에뮬레이터는 실행 후 다음 통계를 출력합니다:

```
Core 0 Status:
  PC: 0x1030
  Cycles: 10
  Instructions: 10
  CPI: 1.0
  Branches: 1 taken, 0 not taken
  Halted: true
```

### 주요 메트릭
- **Cycles**: 실행된 사이클 수
- **Instructions**: 실행된 명령어 수
- **CPI**: Cycles Per Instruction (항상 1.0)
- **Branches**: 분기 통계

---

## 🗺️ OS 개발 로드맵

### ✅ Phase 1: 에뮬레이터 (완료)
- [x] RISC-V 64I 명령어 구현
- [x] M Extension (곱셈/나눗셈)
- [x] MMIO 디바이스 (UART, Timer 등)
- [x] 멀티코어 지원
- [x] 모든 테스트 통과

### 🚧 Phase 2: 베어메탈 커널 (다음 단계)
- [ ] 부트 코드 작성
- [ ] UART 드라이버
- [ ] printf 구현
- [ ] 메모리 관리 (페이지 테이블)
- [ ] 인터럽트 핸들링

### 📅 Phase 3: 프로세스 관리 (예정)
- [ ] 프로세스 구조체
- [ ] 컨텍스트 스위칭
- [ ] Round-Robin 스케줄러
- [ ] 시스템 호출

### 📅 Phase 4-7: 고급 기능 (예정)
- [ ] 동기화 (Mutex, Semaphore)
- [ ] 파일 시스템
- [ ] 네트워킹 (옵션)
- [ ] 사용자 공간

**자세한 로드맵**: [DOCS/OS_ROADMAP.md](DOCS/OS_ROADMAP.md)

---

## 📁 프로젝트 구조

```
risc/
├── Sources/
│   ├── main.swift              # 진입점
│   ├── MultiCoreSystem.swift   # 멀티코어 시스템
│   ├── CoreSimple.swift        # 순차 실행 코어 ⭐ (현재 사용)
│   ├── Core.swift              # 파이프라인 코어 (레거시)
│   ├── SharedMemory.swift      # 공유 메모리
│   ├── MemoryBus.swift         # 메모리 버스
│   ├── Instruction.swift       # 명령어 디코딩
│   ├── MMIODevice.swift        # MMIO 디바이스
│   └── ...
├── Examples/                   # 테스트 프로그램
│   ├── *.s                     # 어셈블리 소스
│   └── *.bin                   # 바이너리
├── Tools/
│   └── simple_assembler.py     # Python 어셈블러
├── DOCS/
│   ├── OS_ROADMAP.md           # OS 개발 로드맵 ⭐
│   ├── UART_TEST_DEBUG_SESSION.md
│   └── ...
└── release/
    └── risc-emulator           # 릴리즈 바이너리 ⭐
```

---

## 🎓 학습 자료

### RISC-V 문서
- [RISC-V ISA Specification](https://riscv.org/specifications/)
- [RISC-V Reader](https://www.riscbook.com/)

### OS 개발
- [OSDev Wiki](https://wiki.osdev.org/)
- [xv6 (MIT OS Course)](https://pdos.csail.mit.edu/6.828/)
- [Writing an OS in Rust](https://os.phil-opp.com/)

### 추천 서적
- "Operating Systems: Three Easy Pieces"
- "Computer Systems: A Programmer's Perspective"
- "The RISC-V Reader"

---

## 🐛 디버깅 팁

### 명령어 실행 추적

```bash
./risc-emulator program.bin --debug
```

출력 예시:
```
[Core 0] PC=0x1000, Instr=0x00000513
[Core 0] PC=0x1004, Instr=0x01400593
...
```

### 레지스터 값 확인

실행 후 자동으로 출력됩니다:
```
Register Contents:
  x10 (a0  ) = 268435456
  x11 (a1  ) = 67
```

### 사이클 제한

무한 루프 방지:
```bash
./risc-emulator program.bin --max-cycles 1000
```

---

## 🚀 다음 단계

### 1. 개발 환경 설정

```bash
# RISC-V GCC Toolchain 설치
brew install riscv-gnu-toolchain

# 또는 apt (Linux)
sudo apt-get install gcc-riscv64-unknown-elf
```

### 2. 첫 번째 OS 코드 작성

```bash
mkdir os-kernel
cd os-kernel

# boot.S 작성 (어셈블리 부트 코드)
# main.c 작성 (C 진입점)
# linker.ld 작성 (링커 스크립트)
```

### 3. 컴파일 및 실행

```bash
riscv64-unknown-elf-gcc -nostdlib -T linker.ld boot.S main.c -o kernel.elf
riscv64-unknown-elf-objcopy -O binary kernel.elf kernel.bin
../risc-emulator kernel.bin
```

**자세한 가이드**: [DOCS/OS_ROADMAP.md](DOCS/OS_ROADMAP.md)

---

## 🤝 기여

이슈 및 기여는 환영합니다!

### 버그 리포트
- 재현 가능한 최소 예제 포함
- 실행 환경 (OS, Swift 버전) 명시

### 기능 제안
- 명확한 사용 사례 설명
- OS 개발에 어떻게 도움이 되는지 설명

---

## 📝 라이선스

MIT License - 교육 목적 사용 환영

---

## 🎯 프로젝트 상태

```
┌─────────────────────────────────────────┐
│  Phase 1: Emulator        ✅ FROZEN     │
│  Phase 2: Bare-Metal      🚧 READY      │
│  Phase 3: Process Mgmt    📅 PLANNED    │
│  Phase 4: Sync & IPC      📅 PLANNED    │
│  Phase 5: File System     📅 PLANNED    │
│  Phase 6: Networking      📅 OPTIONAL   │
│  Phase 7: User Space      📅 PLANNED    │
└─────────────────────────────────────────┘
```

**Current Status**: ✅ **Emulator FROZEN & VERIFIED**  
**Next Phase**: 🚧 **OS Development (Phase 2) - READY TO START**

---

## 📞 연락처

- **Documentation**: `DOCS/` 폴더 참조
- **Examples**: `Examples/` 폴더의 테스트 프로그램
- **Tools**: `Tools/simple_assembler.py` 사용법

---

**Made with ❤️ for RISC-V & OS Learning**

**Version**: 1.0.0 (Emulator Phase - FROZEN)  
**Swift Version**: 5.9+  
**Platform**: macOS (arm64), Linux (x86_64)

🚀 **Ready to build an OS!**
