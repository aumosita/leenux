# Branch-heavy Test Program
# Tests branch prediction with a simple loop

.section .text
.globl _start

_start:
    # Initialize counter
    addi x10, x0, 0      # x10 = counter = 0
    addi x11, x0, 20     # x11 = limit = 20
    
loop:
    # Increment counter
    addi x10, x10, 1     # counter++
    
    # Branch: loop while counter < limit
    blt x10, x11, loop   # if (counter < limit) goto loop
    
    # Loop done
    # Result in x10 should be 20
    
    ebreak
