# UART 테스트 프로그램
# "Hello, RISC-V!" 출력

.section .text
.globl _start

_start:
    # UART 베이스 주소
    lui x10, 0x10000        # x10 = 0x10000000 (UART base)
    
    # 메시지 주소 준비
    auipc x11, 0            # x11 = PC (이 명령어 주소: 0x1004)
    addi x11, x11, 40       # x11 = 0x1004 + 40 = 0x102C (message 위치)
    
print_loop:
    # 문자 로드
    lbu x12, 0(x11)         # x12 = *x11 (현재 문자)
    
    # NULL 체크
    beq x12, x0, end        # if (x12 == 0) goto end
    
    # UART TX로 문자 출력
    sb x12, 0(x10)          # *0x10000000 = x12
    
    # 다음 문자로
    addi x11, x11, 1        # x11++
    j print_loop
    
end:
    # 줄바꿈 출력
    addi x12, x0, 10        # x12 = '\n'
    sb x12, 0(x10)
    
    # 프로그램 종료
    ebreak

# 데이터를 코드 섹션에 포함
message:
    .byte 'H', 'e', 'l', 'l', 'o', ',', ' '
    .byte 'R', 'I', 'S', 'C', '-', 'V', '!', 0
