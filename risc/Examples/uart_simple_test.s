# 더 단순한 UART 테스트 - 3글자만

.section .text
.globl _start

_start:
    lui x10, 0x10000        # UART 주소
    
    # 'A' 출력
    addi x11, x0, 65
    sb x11, 0(x10)
    
    # 'B' 출력
    addi x11, x0, 66
    sb x11, 0(x10)
    
    # 'C' 출력
    addi x11, x0, 67
    sb x11, 0(x10)
    
    # NULL 체크 테스트
    addi x12, x0, 0         # x12 = 0
    beq x12, x0, done       # 같으면 done으로
    
    # 실행되면 안 됨
    addi x11, x0, 88        # 'X'
    sb x11, 0(x10)
    
done:
    ebreak
