# Sub-word loads/stores with sign and zero extension, all byte offsets, merging writes.
        li   s0, 0x200
        li   t0, 0x8081F2E3
        sw   t0, 0(s0)
        lb   a0, 0(s0)        # 0xE3 -> 0xFFFFFFE3
        lb   a1, 1(s0)        # 0xF2 -> 0xFFFFFFF2
        lb   a2, 2(s0)        # 0x81 -> 0xFFFFFF81
        lb   a3, 3(s0)        # 0x80 -> 0xFFFFFF80
        lbu  a4, 0(s0)        # 0xE3
        lbu  a5, 3(s0)        # 0x80
        lh   a6, 0(s0)        # 0xF2E3 -> 0xFFFFF2E3
        lh   a7, 2(s0)        # 0x8081 -> 0xFFFF8081
        lhu  s1, 0(s0)        # 0xF2E3
        lhu  s2, 2(s0)        # 0x8081
        li   t1, 0x11
        sb   t1, 1(s0)        # merge byte 1
        li   t2, 0x2222
        sh   t2, 2(s0)        # merge upper half
        lw   s3, 0(s0)
        sb   t1, 7(s0)        # write into the next word
        sh   t2, 4(s0)
        lw   s4, 4(s0)
        li   t3, -1
        sb   t3, 8(s0)
        lb   s5, 8(s0)        # -1
        lbu  s6, 8(s0)        # 255
        sw   t3, 12(s0)
        sb   x0, 13(s0)
        lw   s7, 12(s0)       # 0xFFFF00FF
        ebreak
