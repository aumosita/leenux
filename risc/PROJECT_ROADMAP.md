# RISC-V OS Development Roadmap

## 🎯 프로젝트 목표

**나만의 OS를 RISC-V 에뮬레이터 위에서 개발하기**

### 핵심 요구사항
1. ✅ 멀티코어 병렬 실행 (호스트 CPU 활용)
2. ✅ 협력형 멀티태스킹 (yield 기반)
3. 🔨 픽셀 기반 터미널 (프레임버퍼)
4. 🔨 한글 입출력
5. 🔨 GUI 위젯 시스템
6. 🔨 메모리 확장 (256MB ~ 1GB)

---

## 📐 아키텍처 개요

```
┌──────────────────────────────────────────────────────────┐
│                    Host System (macOS)                    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            RISC-V Emulator (Swift)                  │ │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐           │ │
│  │  │Core 0│  │Core 1│  │Core 2│  │Core 3│  (병렬)   │ │
│  │  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘           │ │
│  │     │         │         │         │                │ │
│  │     └─────────┴─────────┴─────────┘                │ │
│  │              │                                      │ │
│  │        ┌─────▼─────┐                               │ │
│  │        │Memory Bus │                               │ │
│  │        └─────┬─────┘                               │ │
│  │              │                                      │ │
│  │    ┌─────────┴─────────┐                          │ │
│  │    │  Shared Memory    │ (1GB)                    │ │
│  │    │  ┌──────────────┐ │                          │ │
│  │    │  │ RAM          │ │ 0x0000_0000 - 0x3FFF_FFFF│ │
│  │    │  │ UART         │ │ 0x1000_0000 - 0x1000_0FFF│ │
│  │    │  │ Timer        │ │ 0x1000_1000 - 0x1000_1FFF│ │
│  │    │  │ Framebuffer  │ │ 0x1000_3000 - 0x13FF_FFFF│ │
│  │    │  │ Keyboard     │ │ 0x1400_0000 - 0x1400_0FFF│ │
│  │    │  └──────────────┘ │                          │ │
│  │    └───────────────────┘                          │ │
│  │                                                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Custom OS (RISC-V Binary)                │ │
│  │  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │  Kernel      │  │  System Libs │               │ │
│  │  │  - Syscalls  │  │  - libc      │               │ │
│  │  │  - Scheduler │  │  - GUI       │               │ │
│  │  └──────────────┘  └──────────────┘               │ │
│  │  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │ Drivers      │  │  User Apps   │               │ │
│  │  │  - Console   │  │  - Shell     │               │ │
│  │  │  - Graphics  │  │  - Editor    │               │ │
│  │  └──────────────┘  └──────────────┘               │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 🗓️ Phase 1: 에뮬레이터 완성 (1-2주)

### Week 1: 메모리 확장 & MMIO 기반

#### Day 1-2: 메모리 확장
```swift
// SharedMemory.swift 수정
- 현재: 8MB (기본)
- 목표: 1GB (선택 가능)
- API: init(size: Int) // 바이트 단위
```

**작업:**
- [ ] SharedMemory 크기 확장 (최대 4GB)
- [ ] 메모리 할당 최적화 (필요 시 mmap 사용)
- [ ] 성능 테스트 (1GB 메모리)

#### Day 3-5: 메모리 매핑 I/O (MMIO)
```swift
// 메모리 맵 정의
enum MemoryMap {
    static let RAM_START     = 0x0000_0000
    static let RAM_SIZE      = 0x4000_0000  // 1GB
    
    static let UART_BASE     = 0x1000_0000
    static let TIMER_BASE    = 0x1000_1000
    static let FB_BASE       = 0x1000_3000  // Framebuffer
    static let KB_BASE       = 0x1400_0000  // Keyboard
}
```

**작업:**
- [ ] MMIO 주소 범위 정의
- [ ] Device 프로토콜 설계
  ```swift
  protocol MMIODevice {
      func read(offset: UInt64, size: Int) -> [UInt8]
      mutating func write(offset: UInt64, data: [UInt8])
  }
  ```
- [ ] SharedMemory에 device routing 추가
- [ ] 테스트: MMIO 읽기/쓰기

#### Day 6-7: 기본 디바이스 구현
```swift
// UARTDevice.swift - 콘솔 출력
class UARTDevice: MMIODevice {
    // 0x00: TX data register
    // 0x04: RX data register
    // 0x08: Status register
}

// TimerDevice.swift - 타이머
class TimerDevice: MMIODevice {
    // 0x00: Current time (64-bit)
    // 0x08: Alarm time
}

// FramebufferDevice.swift - 화면 출력
class FramebufferDevice: MMIODevice {
    var width: Int = 1024
    var height: Int = 768
    var pixels: [UInt32]  // ARGB
}
```

**작업:**
- [ ] UARTDevice 구현 (콘솔 출력)
- [ ] TimerDevice 구현
- [ ] FramebufferDevice 구현
- [ ] KeyboardDevice 구현 (입력 버퍼)
- [ ] 시스템 통합

### Week 2: 디바이스 드라이버 & 테스트

#### Day 8-10: 시스템 콜 확장
```swift
// Kernel.swift에 새 시스템 콜 추가
enum Syscall {
    case exit(code: Int64)
    case yield
    case spawn(entry: UInt64)
    
    // 새로 추가
    case print(ptr: UInt64, len: UInt64)     // 문자열 출력
    case read(ptr: UInt64, maxLen: UInt64)   // 키보드 입력
    case getTime() -> UInt64                  // 타이머
    case setPixel(x: UInt64, y: UInt64, color: UInt32)
    case fillRect(x: UInt64, y: UInt64, w: UInt64, h: UInt64, color: UInt32)
}
```

**작업:**
- [ ] print 시스템 콜 (UART 사용)
- [ ] read 시스템 콜 (Keyboard 사용)
- [ ] getTime 시스템 콜
- [ ] setPixel 시스템 콜
- [ ] 테스트 프로그램 작성

#### Day 11-12: GUI 호스트 창 (선택)
```swift
// macOS 앱으로 프레임버퍼 표시
import Cocoa

class EmulatorWindow: NSWindow {
    // FramebufferDevice의 픽셀을 화면에 렌더링
    // 60 FPS 업데이트
}
```

**작업:**
- [ ] NSWindow로 프레임버퍼 출력
- [ ] 키보드 이벤트 → KeyboardDevice
- [ ] 마우스 이벤트 (선택)
- [ ] 실시간 업데이트 (60 FPS)

#### Day 13-14: 최종 테스트 & 문서화
**작업:**
- [ ] 전체 시스템 통합 테스트
- [ ] 성능 벤치마크 (멀티코어 병렬성)
- [ ] API 문서화
- [ ] 예제 프로그램 작성

---

## 🏗️ Phase 2: 프로젝트 분리 (2-3일)

### 에뮬레이터 프로젝트 (현재)
```
risc/
├── Sources/           # Swift 에뮬레이터
├── Tests/
├── Package.swift
├── README.md
└── EMULATOR_API.md    # NEW: API 문서
```

**최종 빌드:**
```bash
# 실행 바이너리
swift build -c release
cp .build/release/risc-emulator ~/bin/riscv-emu

# 라이브러리 모드 (선택)
swift build -c release --product RISC-V-Emulator-Lib
```

### OS 프로젝트 (신규)
```
riscv-os/
├── boot/              # 부트로더
│   └── boot.S
├── kernel/            # 커널
│   ├── syscall.c
│   ├── scheduler.c
│   └── drivers/
│       ├── console.c
│       ├── framebuffer.c
│       └── keyboard.c
├── lib/               # 시스템 라이브러리
│   ├── libc/          # 기본 C 라이브러리
│   └── libgui/        # GUI 프레임워크
├── apps/              # 사용자 앱
│   ├── shell/
│   ├── editor/
│   └── calculator/
├── tools/             # 빌드 도구
│   └── link.ld        # 링커 스크립트
├── Makefile
└── README.md
```

**빌드 시스템:**
```makefile
# Makefile
CC = riscv64-unknown-elf-gcc
AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-ld

CFLAGS = -march=rv64im -mabi=lp64 -O2 -ffreestanding
LDFLAGS = -T tools/link.ld

all: os.bin

os.bin: boot.o kernel.o drivers.o
	$(LD) $(LDFLAGS) -o $@ $^

run: os.bin
	riscv-emu os.bin --cores 4 --memory 256
```

---

## 🚀 Phase 3: OS 개발 (4-12주)

### Week 3-4: 부트 & 기본 시스템
- [ ] 부트로더 작성 (boot.S)
- [ ] 메모리 초기화
- [ ] 스택 설정
- [ ] C 런타임 초기화
- [ ] 커널 진입점

### Week 5-6: 콘솔 & 한글 출력
- [ ] UART 드라이버 (printf)
- [ ] 프레임버퍼 드라이버
- [ ] 한글 폰트 임베드 (16x16 비트맵)
- [ ] UTF-8 인코딩/디코딩
- [ ] 한글 조합 (초성+중성+종성)
- [ ] 가상 터미널 (80x48)

### Week 7-8: 키보드 & 입력
- [ ] 키보드 드라이버
- [ ] 입력 버퍼
- [ ] 한글 입력 (IME)
- [ ] 간단한 셸 구현

### Week 9-10: GUI 프레임워크
- [ ] 기본 그래픽 함수
  - drawLine, drawRect, fillRect, drawCircle
- [ ] 비트맵 렌더링
- [ ] 텍스트 렌더링 (한글 포함)
- [ ] 이벤트 시스템

### Week 11-12: 위젯 시스템
- [ ] Window 클래스
- [ ] Button 위젯
- [ ] TextBox 위젯
- [ ] Label 위젯
- [ ] 이벤트 루프
- [ ] 예제 앱 (계산기)

---

## 🔧 기술 스펙

### 에뮬레이터 스펙
```
- Architecture: RV64IM
- Cores: 1-8 (병렬 실행)
- Memory: 최대 4GB
- Cache: L1 4KB per core
- Pipeline: 5-stage
- Branch Prediction: 1-bit dynamic
```

### 메모리 맵
```
0x0000_0000 - 0x3FFF_FFFF : RAM (1GB)
0x1000_0000 - 0x1000_0FFF : UART
0x1000_1000 - 0x1000_1FFF : Timer
0x1000_2000 - 0x1000_2FFF : Interrupt Controller (미래)
0x1000_3000 - 0x13FF_FFFF : Framebuffer (64MB)
0x1400_0000 - 0x1400_0FFF : Keyboard
```

### 프레임버퍼 스펙
```
Resolution: 1024x768
Format: ARGB8888 (32-bit)
Size: 1024 * 768 * 4 = 3,145,728 bytes (~3MB)
Base Address: 0x1000_3000
```

### 한글 폰트
```
Format: 16x16 비트맵
Encoding: UTF-8
Characters: 완성형 2,350자 + ASCII
Size: 약 75KB
```

---

## 📊 현재 진행 상황

### ✅ 완료
- [x] 멀티코어 시스템 (1-8 cores)
- [x] 5단계 파이프라인
- [x] L1 Cache
- [x] Branch Prediction
- [x] RV64IM 지원
- [x] 협력형 멀티태스킹 기반
- [x] 레거시 모드 제거

### 🔨 진행 중 (2024 업데이트)
- [x] MMIO 프레임워크 ✅
- [x] UART 디바이스 (TX) ✅
- [x] Load-Use Hazard 수정 ✅
- [ ] UART 루프 테스트 완료 (진행 중)

### 📅 예정
- [ ] 디바이스 드라이버
- [ ] 시스템 콜 확장
- [ ] GUI 호스트 창
- [ ] 프로젝트 분리
- [ ] OS 개발

---

## 🎯 마일스톤

### M1: 에뮬레이터 완성 (2주)
- 메모리 1GB 지원
- MMIO 프레임워크
- 기본 디바이스 (UART, Timer, Framebuffer, Keyboard)
- 시스템 콜 확장
- GUI 호스트 창

### M2: 프로젝트 분리 (3일)
- 에뮬레이터 동결 & 바이너리 빌드
- OS 프로젝트 템플릿
- 빌드 시스템

### M3: OS 부트 (2주)
- 부트로더
- 커널 초기화
- 콘솔 출력 (ASCII)

### M4: 한글 지원 (2주)
- 한글 폰트
- 한글 출력
- 한글 입력 (IME)
- 가상 터미널

### M5: GUI 기본 (2주)
- 그래픽 함수
- 이벤트 시스템
- 간단한 앱

### M6: 위젯 시스템 (4주)
- 위젯 클래스들
- 이벤트 처리
- 예제 앱들

---

## 💡 다음 액션

### 즉시 (이번 주)
1. **메모리 확장 구현**
   ```swift
   // SharedMemory.swift
   init(size: Int = 1024 * 1024 * 1024) // 1GB 기본
   ```

2. **MMIO 프레임워크 설계**
   ```swift
   // MMIODevice.swift
   protocol MMIODevice { ... }
   ```

3. **간단한 UART 구현**
   ```swift
   // UARTDevice.swift
   class UARTDevice: MMIODevice {
       func write(_ byte: UInt8) {
           print(String(UnicodeScalar(byte)))
       }
   }
   ```

### 다음 주
1. Framebuffer 구현
2. Keyboard 구현
3. 시스템 콜 확장
4. 테스트 프로그램

---

**작성일**: 2024  
**최종 업데이트**: 2024 (UART 디버깅 완료)  
**상태**: Phase 1 - Week 1 (90% 완료) ✅  
**다음 단계**: 
- uart_test.s 루프 수정
- Phase 1 - Week 2 시작 (시스템 콜 확장)

---

## 📝 최근 업데이트 (2024)

### Load-Use Hazard 버그 수정 ✅
**문제**: `tick()` 함수에서 stall 로직이 `fetch()`에만 있고 `execute()`/`decode()`는 스킵하지 않음

**해결**: 
```swift
if stallCycles > 0 {
    stallCycles -= 1
    // decode()와 execute() 스킵
} else if !memStalled {
    execute()
    decode()
}
```

**결과**: 
- uart_simple.s: ✅ 정상 작동
- uart_test.s: ⚠️ 첫 글자 'H' 출력 성공 (루프 문제 남음)

### 완료된 컴포넌트
- [x] UART 디바이스 구현
- [x] MMIO 프레임워크
- [x] 파이프라인 Hazard 처리
- [x] 동기식 메모리 접근

### 상세 문서
- `DOCS/UART_DEBUGGING_SUCCESS.md`: 디버깅 사례 연구
- `DOCS/HARDWARE_STATUS.md`: 하드웨어 에뮬레이션 현황
- `UART_DEBUG_LOG.md`: 전체 디버깅 로그
