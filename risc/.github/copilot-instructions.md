# RISC-V 64I Emulator (Swift)

- [x] Clarify Project Requirements
- [x] Scaffold the Project
- [x] Customize the Project
- [x] Install Required Extensions
- [x] Compile the Project
- [x] Create and Run Task
- [x] Launch the Project
- [x] Ensure Documentation is Complete

## Project Overview
Swift로 RISC-V 64I 프로세서 에뮬레이터를 구현합니다. CPU, Memory, Instruction, Emulator 등 주요 컴포넌트별 파일 구조를 포함하며, 명령어 fetch-decode-execute 루프와 기본 레지스터/메모리 구조를 구현합니다.

## 완료된 작업
- RISC-V 64I 명령어 디코더 구현 (Instruction.swift)
- CPU 명령어 실행 로직 구현 (Cpu.swift) - ADD, ADDI, LOAD/STORE, BRANCH, JUMP 등
- 메모리 접근 및 예외 처리 구현 (Memory.swift) - 8/16/32/64비트 지원
- Emulator 실행 루프 종료 조건 및 초기화 구현 (Emulator.swift)
- 샘플 바이너리/프로그램 로딩 기능 추가
- 테스트 코드 작성 및 검증 - 기본 산술 연산 테스트 통과
- 프로젝트 빌드 및 실행 환경 설정 (Swift Package Manager 등)
- README 및 문서 보완
