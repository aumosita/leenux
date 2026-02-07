# Working Shell - Using decimal ASCII values
.section .text
.globl _start

_start:
    li sp, 0x80000
    lui s1, 0x10000        # UART base 0x10000000
    
    # "Leenux Shell v0.1\n"
    li a0, 76              # 'L'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 110             # 'n'
    sb a0, 0(s1)
    li a0, 117             # 'u'
    sb a0, 0(s1)
    li a0, 120             # 'x'
    sb a0, 0(s1)
    li a0, 32              # ' '
    sb a0, 0(s1)
    li a0, 83              # 'S'
    sb a0, 0(s1)
    li a0, 104             # 'h'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 108             # 'l'
    sb a0, 0(s1)
    li a0, 108             # 'l'
    sb a0, 0(s1)
    li a0, 32              # ' '
    sb a0, 0(s1)
    li a0, 118             # 'v'
    sb a0, 0(s1)
    li a0, 48              # '0'
    sb a0, 0(s1)
    li a0, 46              # '.'
    sb a0, 0(s1)
    li a0, 49              # '1'
    sb a0, 0(s1)
    li a0, 10              # '\n'
    sb a0, 0(s1)
    
shell_loop:
    # "leenux> "
    li a0, 108             # 'l'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 110             # 'n'
    sb a0, 0(s1)
    li a0, 117             # 'u'
    sb a0, 0(s1)
    li a0, 120             # 'x'
    sb a0, 0(s1)
    li a0, 62              # '>'
    sb a0, 0(s1)
    li a0, 32              # ' '
    sb a0, 0(s1)
    
    # "format\n"
    li a0, 102             # 'f'
    sb a0, 0(s1)
    li a0, 111             # 'o'
    sb a0, 0(s1)
    li a0, 114             # 'r'
    sb a0, 0(s1)
    li a0, 109             # 'm'
    sb a0, 0(s1)
    li a0, 97              # 'a'
    sb a0, 0(s1)
    li a0, 116             # 't'
    sb a0, 0(s1)
    li a0, 10              # '\n'
    sb a0, 0(s1)
    
    # "Done!\n\n"
    li a0, 68              # 'D'
    sb a0, 0(s1)
    li a0, 111             # 'o'
    sb a0, 0(s1)
    li a0, 110             # 'n'
    sb a0, 0(s1)
    li a0, 101             # 'e'
    sb a0, 0(s1)
    li a0, 33              # '!'
    sb a0, 0(s1)
    li a0, 10              # '\n'
    sb a0, 0(s1)
    li a0, 10              # '\n'
    sb a0, 0(s1)
    
    j shell_loop
