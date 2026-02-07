# 최소 UART 테스트

.section .text
.globl _start

_start:
    # UART 주소를 x10에 직접
    lui x10, 0x10000        # x10 = 0x10000000
    
    # 즉시 'A' 출력
    addi x11, x0, 65        # x11 = 'A'
    sb x11, 0(x10)          # UART TX = 'A'
    
    ebreak
