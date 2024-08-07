# Data-hazard stress: every producer/consumer distance, load-use, store-to-load, x0 writes.
        li   s0, 0x180
        li   a0, 5
        addi a1, a0, 1        # RAW distance 1  (EX/MEM forward)
        addi a2, a1, 1        # chain
        add  a3, a2, a1
        nop
        add  a4, a3, a2       # distance 2 (WB forward)
        nop
        nop
        add  a5, a4, a0       # distance 3 (register-file bypass)
        sw   a5, 0(s0)
        lw   a6, 0(s0)        # store then load
        addi a7, a6, 100      # load-use stall
        lw   t0, 0(s0)
        add  t1, t0, t0       # load-use on both operands
        lw   t2, 0(s0)
        sw   t2, 4(s0)        # load-use into store data
        lw   t3, 4(s0)
        addi x0, t3, 7        # write to x0 must be ignored
        add  t4, x0, t3
        li   t5, 3
        sub  t6, t5, t3       # forwarding into rs2
        slli s1, t6, 3
        sll  s2, s1, t5
        add  s3, s1, s2
        add  s3, s3, s3       # back-to-back same reg
        add  s3, s3, s3
        ebreak
