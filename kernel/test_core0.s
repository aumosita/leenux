# Minimal test: Core 0 prints "A"

.globl _start

_start:
    li a0, 0x10000000     # UART base
    li a1, 65             # 'A'
    sb a1, 0(a0)
    li a1, 10             # '\n'
    sb a1, 0(a0)

loop:
    j loop
