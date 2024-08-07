# jal / jalr / ret, a stack in data RAM, recursive factorial, and an indirect jump.
        li   sp, 0x400
        li   a0, 7
        jal  ra, fact         # a0 = 7! = 5040
        mv   s1, a0
        li   a0, 10
        jal  ra, sumto        # a0 = 55
        mv   s2, a0
        auipc t1, 0           # indirect jump via jalr to a computed address
        addi t1, t1, 12
        jalr t2, t1, 0        # jumps over the next instruction, t2 = return address
        li   s3, 111          # skipped
        li   s4, 222
        ebreak

fact:   addi sp, sp, -8
        sw   ra, 4(sp)
        sw   a0, 0(sp)
        li   t0, 1
        ble  a0, t0, fbase
        addi a0, a0, -1
        jal  ra, fact
        lw   t1, 0(sp)        # load-use into the multiply loop below
        mv   t2, a0
        li   a0, 0
mul:    beqz t1, fdone
        add  a0, a0, t2
        addi t1, t1, -1
        j    mul
fbase:  li   a0, 1
fdone:  lw   ra, 4(sp)
        addi sp, sp, 8
        ret

