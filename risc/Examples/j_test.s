# J 명령어 간단 테스트

.section .text
.globl _start

_start:
    addi x10, x0, 1       # x10 = 1
    j skip                # 점프
    addi x10, x0, 99      # 실행되면 안 됨
skip:
    addi x11, x0, 2       # x11 = 2
    ebreak
