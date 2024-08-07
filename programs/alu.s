# All ALU operations on corner-case operands.
        li   a0, 0x7FFFFFFF
        li   a1, 0x80000000
        li   a2, -1
        li   a3, 1
        li   a4, 31
        add  t0, a0, a3       # overflow wrap
        sub  t1, a1, a3
        and  t2, a0, a2
        or   t3, a1, a3
        xor  t4, a0, a2
        sll  t5, a3, a4
        srl  t6, a1, a4
        sra  s1, a1, a4
        slt  s2, a1, a0       # signed: min < max -> 1
        sltu s3, a1, a0       # unsigned: 0x80000000 > 0x7FFFFFFF -> 0
        slt  s4, a2, a3       # -1 < 1 -> 1
        sltu s5, a2, a3       # 0xFFFFFFFF < 1 -> 0
        slti s6, a2, 0        # 1
        sltiu s7, a2, -1      # 0xFFFFFFFF < 0xFFFFFFFF -> 0
        sltiu s8, a3, -1      # 1 < 0xFFFFFFFF -> 1
        andi s9, a2, 0x7FF
        ori  s10, a1, 0x555
        xori s11, a0, -1
        slli a5, a3, 20
        srli a6, a1, 4
        srai a7, a1, 4
        lui  gp, 0xABCDE
        auipc tp, 0x1
        addi sp, gp, -1
        sub  ra, x0, a3
        ebreak
