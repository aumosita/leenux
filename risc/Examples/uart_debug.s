# UART 디버그 - 주소 확인

.section .text
.globl _start

_start:
    # 방법 1: LUI만 사용
    lui x10, 0x10000        # x10 = 0x10000000 ?
    
    # 'H' 출력 시도
    addi x11, x0, 72        # x11 = 'H'
    sb x11, 0(x10)          # Store to x10 + 0
    
    # 방법 2: LUI + ADDI 조합으로 정확한 주소
    lui x20, 0x10000        # x20 = 0x10000 << 12 = 0x10000000
    addi x20, x20, 0        # x20 = x20 + 0 = 0x10000000
    
    # 'i' 출력
    addi x21, x0, 105       # x21 = 'i'
    sb x21, 0(x20)          # Store to 0x10000000
    
    # 종료
    ebreak
