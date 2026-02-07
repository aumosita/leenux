# BEQ 테스트

.section .text
.globl _start

_start:
    addi x10, x0, 0       # x10 = 0
    addi x11, x0, 0       # x11 = 0
    beq x10, x11, equal   # 같으면 equal로
    addi x12, x0, 99      # 실행되면 안 됨
equal:
    addi x12, x0, 42      # x12 = 42
    ebreak
