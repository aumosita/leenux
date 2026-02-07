# 간단한 UART 테스트
# 'H', 'i', '!' 출력

.section .text
.globl _start

_start:
    # UART 베이스 주소 (0x10000000)
    lui x10, 0x10000        # x10 = 0x10000000
    
    # 'H' 출력
    addi x11, x0, 72        # x11 = 'H' (ASCII 72)
    sb x11, 0(x10)          # UART TX = 'H'
    
    # 'i' 출력  
    addi x11, x0, 105       # x11 = 'i' (ASCII 105)
    sb x11, 0(x10)          # UART TX = 'i'
    
    # '!' 출력
    addi x11, x0, 33        # x11 = '!' (ASCII 33)
    sb x11, 0(x10)          # UART TX = '!'
    
    # '\n' 출력
    addi x11, x0, 10        # x11 = '\n' (ASCII 10)
    sb x11, 0(x10)          # UART TX = '\n'
    
    # 종료
    ebreak
