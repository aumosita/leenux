# RISC-V OS Development Roadmap

## Phase 1: Emulator ✅ COMPLETED

에뮬레이터 구현 완료 및 검증

## Phase 2: Bare-Metal Kernel (다음 단계)

**목표**: OS 없이 하드웨어 직접 제어

### 구현 항목
- [ ] 부트 코드 (boot.S)
- [ ] UART 드라이버
- [ ] printf 구현
- [ ] 메모리 관리 (페이지 테이블)
- [ ] 인터럽트 핸들링

**예상 기간**: 2-3주

## Phase 3: Process Management

**목표**: 멀티태스킹 및 스케줄링

- [ ] 프로세스 구조체
- [ ] 컨텍스트 스위칭
- [ ] Round-Robin 스케줄러
- [ ] 시스템 호출

**예상 기간**: 3-4주

## Phase 4: Synchronization & IPC

- [ ] Mutex, Semaphore
- [ ] 메시지 큐
- [ ] 공유 메모리

**예상 기간**: 2-3주

## Phase 5: File System

- [ ] VFS (Virtual File System)
- [ ] 간단한 파일 시스템
- [ ] RAMDisk

**예상 기간**: 3-4주

## Phase 6: Networking (Optional)

- [ ] 네트워크 인터페이스
- [ ] IP/UDP 스택
- [ ] 소켓 API

**예상 기간**: 4-5주

## Phase 7: User Space

- [ ] 사용자/커널 모드 분리
- [ ] ELF 로더
- [ ] Shell & 기본 유틸리티

**예상 기간**: 3-4주

---

**총 예상 기간**: 4-6개월

**다음 단계**: RISC-V GCC Toolchain 설치
\`\`\`bash
brew install riscv-gnu-toolchain
\`\`\`
