# Iterative Fibonacci: fib(0..24) stored to memory at 0x100, result fib(24) in a0.
        li   s0, 0x100        # base of result array
        li   t0, 0            # fib(n-1)
        li   t1, 1            # fib(n)
        li   t2, 0            # i
        li   t3, 25
loop:   slli t4, t2, 2
        add  t4, t4, s0
        sw   t0, 0(t4)
        add  t5, t0, t1
        mv   t0, t1
        mv   t1, t5
        addi t2, t2, 1
        blt  t2, t3, loop
        lw   a0, 96(s0)       # fib(24) = 46368  (load-use next)
        addi a1, a0, 1
        ebreak
