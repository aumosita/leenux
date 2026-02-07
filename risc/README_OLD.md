# RISC-V Multi-Core Emulator (Swift)

이 프로젝트는 Swift로 작성된 **교육용** RISC-V 64I 멀티코어 프로세서 에뮬레이터입니다.

## 📖 프로젝트 목적

이 에뮬레이터는 다음을 학습하기 위해 설계되었습니다:
- ✅ RISC-V ISA (Instruction Set Architecture)
- ✅ 파이프라인 아키텍처와 해저드 처리
- ✅ 캐시 메모리와 성능 최적화
- ✅ 멀티코어 시스템과 동기화
- ✅ 컴퓨터 아키텍처 개념 전반

## 🚀 주요 기능

### 멀티코어 시스템
- **코어 수**: 1-16개 (설정 가능)
- **공유 메모리**: Thread-safe 8MB RAM
- **메모리 버스**: Round-robin arbitration
- **동기화**: Lock-based synchronization

### 성능 최적화
- **L1 Data Cache**: 4KB direct-mapped cache
  - Hit latency: 1 cycle
  - Miss latency: 10 cycles
  - Hit rate: ~93%
- **Branch Prediction**: 1-bit dynamic predictor
  - Prediction accuracy: ~93%
  - Misprediction tracking
- **Pipeline**: 5-stage pipeline per core
  - IF, ID, EX, MEM, WB
  - Hazard detection & forwarding

### 확장 지원
- ✅ **RV64I**: Base integer instruction set
- ✅ **M Extension**: Multiplication and division
- ⏳ **A Extension**: Atomic instructions (planned)

## 🎯 실행 모드

### 1️⃣ 파이프라인 모드 (기본, 권장)
**현대 프로세서 시뮬레이션 - 성능 최적화 학습**

```bash
.build/debug/risc-emulator program.bin
# 또는
.build/debug/risc-emulator program.bin --cores 4
```

**특징:**
- ✅ 5단계 파이프라인 (IF, ID, EX, MEM, WB)
- ✅ L1 Data Cache (4KB)
- ✅ Branch Prediction (1-bit)
- ✅ Hazard Detection & Forwarding
- ✅ 멀티코어 지원 (1-8 cores)
- ✅ 메모리 버스 중재
- ✅ 성능 통계 (CPI, cache hit rate 등)

**적합한 사용자:**
- 🎓 컴퓨터 구조를 학습하는 학생
- 🔬 성능 최적화를 연구하는 연구자
- 💻 실제 프로세서 동작을 이해하려는 개발자

### 2️⃣ 레거시 모드 (교육용)
**⚠️ DEPRECATED: 교육 목적으로만 사용**

```bash
.build/debug/risc-emulator program.bin --legacy
```

**특징:**
- 📚 단순한 명령어 단위 실행 (1 instruction = 1 step)
- 📚 파이프라인, 캐시, 해저드 없음
- 📚 RISC-V ISA 학습에 최적화
- 📚 디버깅과 추적 용이
- ⚠️ 비현실적인 성능 모델 (CPI = 1.0)

**적합한 사용자:**
- 🔰 RISC-V 명령어를 처음 배우는 초보자
- 🐛 명령어 동작을 단계별로 확인하려는 디버거
- 📖 간단한 프로토타이핑

**중요 경고:**
```
⚠️  레거시 모드는 v2.0에서 제거될 예정입니다.
    파이프라인 모드 사용을 권장합니다.
    
    레거시 모드는 교육 목적으로만 유지되며,
    실제 프로세서 동작과는 차이가 있습니다.
```

### 📊 두 모드 비교

| 특징 | 파이프라인 모드 | 레거시 모드 |
|------|----------------|------------|
| **파이프라인** | ✅ 5단계 | ❌ 없음 |
| **캐시** | ✅ L1 4KB | ❌ 없음 |
| **분기 예측** | ✅ 동적 | ❌ 없음 |
| **멀티코어** | ✅ 1-8 cores | ❌ 단일 |
| **CPI** | 1.2-4.0 (현실적) | 1.0 (이상적) |
| **학습 목적** | 성능 최적화 | 명령어 이해 |
| **복잡도** | 높음 | 낮음 |
| **디버깅** | 어려움 | 쉬움 |
| **권장 사용** | ✅ 메인 사용 | 📚 학습 보조 |

### 🚀 학습 로드맵

```
Step 1: 레거시 모드로 시작 (1-2주)
  └─ RISC-V 명령어 형식과 동작 이해
  └─ 간단한 프로그램 작성 및 실행
  └─ 레지스터와 메모리 개념 학습

Step 2: 파이프라인 모드로 전환 (2-4주)
  └─ 파이프라인 단계별 동작 이해
  └─ 해저드와 stall 현상 관찰
  └─ 캐시 효과 분석
  └─ 성능 메트릭 해석

Step 3: 멀티코어 시스템 (4-8주)
  └─ 멀티코어로 확장
  └─ 메모리 버스 충돌 분석
  └─ 병렬 프로그래밍 실험
  └─ 성능 스케일링 측정
```

## 주요 컴포넌트

### 파이프라인 모드 컴포넌트
- **Core**: 5-stage pipeline with hazard handling
- **L1 Cache**: Per-core 4KB direct-mapped cache
- **Branch Predictor**: 1-bit dynamic predictor
- **Pipeline**: Hazard detection & data forwarding
- **MultiCoreSystem**: Multi-core orchestration
- **SharedMemory**: Thread-safe memory
- **MemoryBus**: Round-robin arbitration

### 레거시 모드 컴포넌트
- **Emulator**: Simple instruction-by-instruction execution
- **Cpu**: Basic RISC-V instruction implementation
- **Memory**: Flat memory model

## 지원되는 명령어

### 산술 연산 (R-type, I-type)
- `ADD`, `SUB`, `ADDI`
- `AND`, `OR`, `XOR`, `ANDI`, `ORI`, `XORI`
- `SLL`, `SRL`, `SRA`, `SLLI`, `SRLI`, `SRAI`
- `SLT`, `SLTU`, `SLTI`, `SLTIU`

### M 확장 (곱셈/나눗셈)
- **곱셈**: `MUL`, `MULH`, `MULHSU`, `MULHU`
- **나눗셈**: `DIV`, `DIVU`, `REM`, `REMU`

### 메모리 연산
- **Load**: `LB`, `LH`, `LW`, `LD`, `LBU`, `LHU`, `LWU`
- **Store**: `SB`, `SH`, `SW`, `SD`

### 분기 및 점프
- **Branch**: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- **Jump**: `JAL`, `JALR`

### 기타
- `LUI`, `AUIPC`
- `EBREAK` (프로그램 종료)

## 실행 방법

### 빌드
```bash
swift build
```

### 단일 코어 실행
```bash
# 기본 실행 (8MB 메모리)
.build/debug/risc-emulator Examples/09_m_extension_simple.bin

# 디버그 모드
.build/debug/risc-emulator Examples/01_arithmetic.bin --debug

# 최대 사이클 수 지정
.build/debug/risc-emulator program.bin --max-cycles 10000

# 큰 메모리 사용 (64MB)
.build/debug/risc-emulator program.bin --memory 64
```

### 멀티코어 실행
```bash
# 4개 코어로 실행
.build/debug/risc-emulator Examples/10_multicore_test.bin --cores 4

# 8개 코어, 최대 사이클 지정
.build/debug/risc-emulator program.bin --cores 8 --max-cycles 50000

# 멀티코어 + 큰 메모리 (512MB)
.build/debug/risc-emulator program.bin --cores 8 --memory 512
```

### 레거시 모드 (교육 목적)
```bash
# ⚠️ DEPRECATED: 레거시 모드 (단순 실행)
.build/debug/risc-emulator program.bin --legacy

# 레거시 모드 + 디버그
.build/debug/risc-emulator program.bin --legacy --debug

# 레거시 모드 + 최대 스텝 지정
.build/debug/risc-emulator program.bin --legacy --max-steps 5000
```

**⚠️ 주의사항:**
- 레거시 모드는 파이프라인 모드와 다른 결과를 낼 수 있습니다
- 교육 및 디버깅 목적으로만 사용하세요
- 프로덕션 사용 시 파이프라인 모드를 권장합니다

### 메모리 크기 옵션
```bash
# 8 MB (기본값)
.build/debug/risc-emulator program.bin

# 64 MB
.build/debug/risc-emulator program.bin --memory 64

# 128 MB
.build/debug/risc-emulator program.bin --memory 128

# 1 GB
.build/debug/risc-emulator program.bin --memory 1024

# 4 GB (멀티코어와 함께)
.build/debug/risc-emulator program.bin --cores 8 --memory 4096
```

### 도움말
```bash
.build/debug/risc-emulator --help
```

## 예제 프로그램

### 기본 테스트
- **01_arithmetic.bin**: 산술 연산 테스트
- **02_memory.bin**: 메모리 로드/스토어
- **03_branches.bin**: 분기 명령어
- **04_function_call.bin**: 함수 호출 및 스택
- **05_comprehensive.bin**: 종합 테스트

### M 확장 테스트
- **06_m_extension_factorial.bin**: 팩토리얼 (10! = 3628800)
- **07_m_extension_division.bin**: 나눗셈 테스트
- **08_m_extension_gcd.bin**: 최대공약수 (GCD)
- **09_m_extension_simple.bin**: 간단한 M 확장

### 멀티코어 테스트
- **10_multicore_test.bin**: 멀티코어 기본 테스트
- **11_branch_test.bin**: Branch prediction 테스트
- **11_branch_loop.bin**: Loop prediction 테스트
- **12_memory_intensive.bin**: 메모리 집약적 테스트

### 실행 예시
```bash
# 단일 코어 테스트
.build/debug/risc-emulator Examples/09_m_extension_simple.bin

# 멀티코어 테스트
.build/debug/risc-emulator Examples/10_multicore_test.bin --cores 4

# Branch prediction 테스트
.build/debug/risc-emulator Examples/11_branch_loop.bin

# 메모리 집약적 테스트
.build/debug/risc-emulator Examples/12_memory_intensive.bin --cores 4
```

## 성능 통계

에뮬레이터는 다양한 성능 통계를 제공합니다:

### 코어 통계
- **Cycles**: 실행된 총 사이클 수
- **Instructions**: 실행된 명령어 수
- **CPI**: Cycles Per Instruction
- **Stalls**: 파이프라인 stall 횟수
- **Branch mispredictions**: 분기 예측 실패 횟수

### 캐시 통계
- **Hit rate**: 캐시 적중률
- **Miss rate**: 캐시 미스율
- **AMAT**: Average Memory Access Time
- **Evictions**: 캐시 라인 교체 횟수

### 메모리 버스 통계
- **Total requests**: 총 메모리 요청 수
- **Conflicts**: 버스 충돌 횟수
- **Conflict rate**: 충돌률
- **Average wait**: 평균 대기 시간

## 자신의 프로그램 만들기

### Python 어셈블러 사용

```bash
python3 Tools/simple_assembler.py <input.s> <output.bin>
```

예시:
```bash
python3 Tools/simple_assembler.py my_program.s my_program.bin
.build/debug/risc-emulator my_program.bin
```

### 어셈블리 예제
```assembly
# 간단한 덧셈 프로그램
.section .text
.globl _start

_start:
    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 20      # x2 = 20
    add x3, x1, x2       # x3 = 30
    ebreak               # 종료
```

### 멀티코어 프로그램 예제
```assembly
# 각 코어가 독립적으로 실행
.section .text
.globl _start

_start:
    # 간단한 계산
    addi x10, x0, 10
    addi x11, x0, 5
    add x12, x10, x11
    ebreak
```

## 프로젝트 구조

```
risc/
├── Sources/
│   ├── main.swift           # 메인 진입점
│   ├── MultiCoreSystem.swift # 멀티코어 시스템
│   ├── Core.swift           # 코어 (5-stage pipeline)
│   ├── Pipeline.swift       # 파이프라인 레지스터
│   ├── SharedMemory.swift   # 공유 메모리
│   ├── MemoryBus.swift      # 메모리 버스
│   ├── Cache.swift          # L1 캐시
│   └── (legacy files)       # 레거시 단일 코어
├── Examples/
│   ├── *.s                  # 어셈블리 소스
│   └── *.bin                # 컴파일된 바이너리
├── Tools/
│   └── simple_assembler.py  # Python 어셈블러
└── README.md
```

## 기술 세부사항

### 메모리 구조
- **프로그램 시작 주소**: `0x1000`
- **스택 포인터 초기값**: `0x10000`
- **메모리 크기**: 8MB
- **엔디안**: Little-endian
- **명령어 크기**: 32비트 (고정)

### 캐시 구조
- **Type**: Direct-mapped
- **Size**: 4KB per core
- **Block size**: 64 bytes
- **Sets**: 64
- **Hit latency**: 1 cycle
- **Miss latency**: 10 cycles

### 파이프라인
- **Stages**: IF, ID, EX, MEM, WB
- **Hazard detection**: Load-use hazard
- **Forwarding**: EX-EX, MEM-EX
- **Branch handling**: Prediction + flush on misprediction

### 메모리 버스
- **Arbitration**: Round-robin
- **Latency**: Configurable (default: 1 cycle)
- **Conflict detection**: Yes
- **Statistics**: Comprehensive

## 성능 벤치마크

### 단일 코어 (with cache)
```
Program: 09_m_extension_simple.bin
Cycles: 25
Instructions: 21
CPI: 1.19
Cache hit rate: 93.75%
AMAT: 1.62 cycles
```

### 멀티코어 (4 cores)
```
Program: 12_memory_intensive.bin
Total cycles: 21
Total instructions: 60
Average IPC: 2.86
Cache hit rate: ~90%
Bus conflicts: 0%
```

## 향후 계획

### 완료된 기능
- [x] RV64I Base instruction set
- [x] M 확장 (곱셈/나눗셈)
- [x] 멀티코어 시스템
- [x] 5-stage pipeline
- [x] L1 Data Cache
- [x] Branch prediction
- [x] Memory bus arbitration

### 진행 중
- [⏳] A 확장 (Atomic instructions)
  - LR/SC 구조 설계 완료
  - AMO 함수 준비됨
  - Core 통합 필요

### 계획
- [ ] L2 Cache (shared)
- [ ] Cache coherence (MESI/MOESI)
- [ ] 2-way set-associative cache
- [ ] CSR 레지스터
- [ ] 시스템 호출 (ECALL)
- [ ] F/D 확장 (Floating-point)
- [ ] 성능 카운터
- [ ] 메모리 매핑된 I/O

## 검증 결과

### 단일 코어 테스트
✅ **01_arithmetic.bin**: 16 steps, x3=100  
✅ **02_memory.bin**: 25 steps, 메모리 연산 성공  
✅ **04_function_call.bin**: 12 steps, x10=12  
✅ **05_comprehensive.bin**: 27 steps, x31=123  
✅ **07_m_extension_division.bin**: 15 steps, x3=14  
✅ **09_m_extension_simple.bin**: 21 instructions, CPI=1.19

### 멀티코어 테스트
✅ **10_multicore_test.bin**: 4 cores, IPC=1.71  
✅ **11_branch_loop.bin**: Branch prediction 93%+  
✅ **12_memory_intensive.bin**: 4 cores, IPC=2.86

### 성능 개선
- **Cache 없음**: CPI ~3.0
- **Cache 있음**: CPI 1.19
- **성능 향상**: **2.5배**

## 📚 문서

### 주요 문서
- **[레거시 모드 분석](LEGACY_MODE_ANALYSIS.md)**: 레거시 vs 파이프라인 모드 비교
- **Branch Prediction**: 분기 예측 알고리즘 상세
- **Memory Bus Arbitration**: 메모리 버스 중재 메커니즘
- **L1 Cache**: 캐시 구조와 성능 분석
- **A Extension Plan**: Atomic 명령어 구현 계획

### FAQ

**Q: 어떤 모드를 사용해야 하나요?**
- A: 대부분의 경우 **파이프라인 모드**(기본값)를 사용하세요.
  - RISC-V 명령어를 처음 배운다면: 레거시 모드로 시작
  - 성능 최적화를 학습한다면: 파이프라인 모드
  - 멀티코어를 실험한다면: 파이프라인 모드 (--cores)

**Q: 레거시 모드는 언제 사용하나요?**
- A: 다음 상황에서만 사용을 권장합니다:
  - RISC-V 명령어 동작을 단계별로 이해하고 싶을 때
  - 복잡한 파이프라인 없이 프로그램을 디버깅할 때
  - 파이프라인 모드의 정확성을 검증할 때

**Q: 두 모드의 결과가 다른데 어느 것이 정확한가요?**
- A: 레거시 모드가 **명령어 시맨틱**은 더 정확합니다.
  - 레거시: 명령어 하나씩 순차 실행 (정답)
  - 파이프라인: 병렬 실행 + 최적화 (실제 프로세서와 유사)
  - 최종 레지스터 값은 동일해야 하지만, 중간 상태는 다를 수 있습니다

**Q: 성능 통계를 어떻게 해석하나요?**
- A: 주요 메트릭 가이드:
  - **CPI (Cycles Per Instruction)**:
    - 1.0에 가까울수록 효율적
    - 3.0 이상이면 많은 stall 발생
  - **Cache Hit Rate**:
    - 90% 이상이면 우수
    - 70% 이하면 cache miss 문제 있음
  - **IPC (Instructions Per Cycle)**:
    - 멀티코어 환경에서 중요
    - 코어 수에 비례하여 증가하는지 확인

**Q: 새 명령어를 추가하고 싶은데요?**
- A: 다음 순서를 권장합니다:
  1. `Cpu.swift`에 레거시 구현 추가 (간단)
  2. 레거시 모드로 테스트 및 검증
  3. `Core.swift`에 파이프라인 구현 추가 (복잡)
  4. 양쪽 모드 결과 비교 테스트

## 🗺️ 로드맵

### v1.0 (현재)
- ✅ RV64I + M Extension
- ✅ 5-stage pipeline
- ✅ L1 Cache
- ✅ Branch Prediction
- ✅ Multi-core (1-8)
- ✅ Legacy mode (교육용)

### v1.5 (3개월)
- 🔨 A Extension (Atomic)
- 🔨 레거시 모드 deprecation 경고
- 🔨 Simple mode 추가 (파이프라인 없는 정확한 실행)
- 🔨 회귀 테스트 강화

### v2.0 (12개월)
- 🚀 레거시 모드 제거
- 🚀 L2 Cache (shared)
- 🚀 Cache coherence (MESI)
- 🚀 CSR 레지스터
- 🚀 F/D Extension (Floating-point)

## ⚠️ 알려진 제한사항

1. **레거시 vs 파이프라인 모드 차이**
   - 동일한 프로그램에서 다른 중간 결과 가능
   - 최종 레지스터 값은 동일해야 함 (불일치 시 버그)

2. **성능 모델 정확도**
   - 캐시 레이턴시는 단순화됨
   - 실제 하드웨어와 다를 수 있음
   - 교육 목적으로 충분한 수준

3. **멀티코어 제한**
   - 최대 8개 코어
   - Cache coherence 미구현 (데이터 일관성 이슈 가능)

4. **메모리 모델**
   - Weak ordering model
   - Memory fence 미지원

## 🤝 기여

문의 및 기여는 언제든 환영합니다!

### 기여 가이드라인
1. 새 기능 추가 시 레거시/파이프라인 양쪽 모두 구현
2. 테스트 케이스 추가 필수
3. 성능 영향 분석 포함

### 버그 리포트
- 레거시와 파이프라인 모드 결과 불일치 발견 시 즉시 보고
- 재현 가능한 최소 예제 포함

---

**Made with ❤️ in Swift**

**License**: MIT (교육 목적 사용 환영)  
**Author**: RISC-V Enthusiasts  
**Version**: 1.0.0
