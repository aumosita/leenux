# Minimal test: Core 1 prints "B"

.globl _start

_start:
    li a0, 0x10000000     # UART base
    li a1, 66             # 'B'
    sb a1, 0(a0)
    li a1, 10             # '\n'
    sb a1, 0(a0)

loop:
    j loop
