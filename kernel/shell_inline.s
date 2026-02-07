# Minimal Shell - Inline UART output
# No data section, all characters written directly

.section .text
.globl _start

_start:
    li sp, 0x80000
    lui s1, 0x10000        # UART base = 0x10000000
    
    # Print "Leenux Shell v0.1\n"
    li a0, 'L'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, 'n'
    sb a0, 0(s1)
    li a0, 'u'
    sb a0, 0(s1)
    li a0, 'x'
    sb a0, 0(s1)
    li a0, ' '
    sb a0, 0(s1)
    li a0, 'S'
    sb a0, 0(s1)
    li a0, 'h'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, 'l'
    sb a0, 0(s1)
    li a0, 'l'
    sb a0, 0(s1)
    li a0, ' '
    sb a0, 0(s1)
    li a0, 'v'
    sb a0, 0(s1)
    li a0, '0'
    sb a0, 0(s1)
    li a0, '.'
    sb a0, 0(s1)
    li a0, '1'
    sb a0, 0(s1)
    li a0, 0x0A
    sb a0, 0(s1)
    
shell_loop:
    # Print "leenux> "
    li a0, 'l'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, 'n'
    sb a0, 0(s1)
    li a0, 'u'
    sb a0, 0(s1)
    li a0, 'x'
    sb a0, 0(s1)
    li a0, '>'
    sb a0, 0(s1)
    li a0, ' '
    sb a0, 0(s1)
    
    # Print "format\n"
    li a0, 'f'
    sb a0, 0(s1)
    li a0, 'o'
    sb a0, 0(s1)
    li a0, 'r'
    sb a0, 0(s1)
    li a0, 'm'
    sb a0, 0(s1)
    li a0, 'a'
    sb a0, 0(s1)
    li a0, 't'
    sb a0, 0(s1)
    li a0, 0x0A
    sb a0, 0(s1)
    
    # Print "Done!\n"
    li a0, 'D'
    sb a0, 0(s1)
    li a0, 'o'
    sb a0, 0(s1)
    li a0, 'n'
    sb a0, 0(s1)
    li a0, 'e'
    sb a0, 0(s1)
    li a0, '!'
    sb a0, 0(s1)
    li a0, 0x0A
    sb a0, 0(s1)
    li a0, 0x0A
    sb a0, 0(s1)
    
    # Loop (will run 2-3 times before max cycles)
    j shell_loop
