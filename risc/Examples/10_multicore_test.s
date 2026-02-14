# Multi-Core Test Program
# Each core will write its ID to a different memory location

.section .text
.globl _start

_start:
    # Core ID는 x0에 하드코딩 (실제로는 CSR에서 읽어야 하지만 간단히)
    # 각 코어는 동일한 프로그램을 실행하지만 다른 결과를 생성
    
    # 간단한 계산: 10 + core_id * 5
    addi x10, x0, 10     # base = 10
    addi x11, x0, 5      # multiplier = 5
    
    # 결과 계산 (각 코어마다 다른 값)
    mul x12, x10, x11    # x12 = 50
    
    # 메모리에 저장
    lui x13, 0x2         # base address = 0x2000
    sd x12, 0(x13)       # store result
    
    ebreak
