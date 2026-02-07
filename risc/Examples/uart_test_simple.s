# UART 테스트 - 간단 버전
# 메시지 메모리 읽기 테스트

.section .text
.globl _start

_start:
    # UART 베이스 주소
    lui x10, 0x10000        # x10 = 0x10000000
    
    # 메시지 주소
    lui x11, 0x1            # x11 = 0x1000  
    addi x11, x11, 0x18     # x11 = 0x1018
    
    # 첫 번째 문자 읽기
    lbu x12, 0(x11)         # x12 = *0x1020
    
    # UART로 출력
    sb x12, 0(x10)
    
    # 종료
    ebreak

.section .data
message:
    .byte 'H', 'e', 'l', 'l', 'o', 0
