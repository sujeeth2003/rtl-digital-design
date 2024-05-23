// Simulation wrapper that instantiates every tier-0 block at a fixed width so a
// single C++ testbench (tb/tier0_tb.cpp) can exercise all of them.
module tier0_top (
    input  logic        clk, rst_n,
    // combinational blocks
    input  logic [15:0] a, b,
    input  logic        cin,
    input  logic [1:0]  sh_mode,
    input  logic [3:0]  sh_amt,
    input  logic [7:0]  req,
    output logic [15:0] rca_sum,  output logic rca_cout,
    output logic [15:0] cla_sum,  output logic cla_cout,
    output logic [15:0] mul_p,
    output logic [2:0]  enc_idx,  output logic enc_valid,
    output logic [15:0] shf,
    // sequential blocks
    input  logic        en, load, up, d_in, ser_in, bit_in,
    input  logic [7:0]  load_val, par_in,
    input  logic [1:0]  sr_mode,
    output logic        dff_a_q, dff_s_q,
    output logic [7:0]  cnt, sr_q,
    output logic        detected
);
    ripple_adder #(16) u_rca (.a(a), .b(b), .cin(cin), .sum(rca_sum), .cout(rca_cout));
    cla_adder    #(16) u_cla (.a(a), .b(b), .cin(cin), .sum(cla_sum), .cout(cla_cout));
    array_multiplier #(8) u_mul (.a(a[7:0]), .b(b[7:0]), .p(mul_p));
    priority_encoder #(8) u_enc (.req(req), .idx(enc_idx), .valid(enc_valid));
    barrel_shifter #(16) u_shf (.din(a), .amt(sh_amt), .mode(sh_mode), .dout(shf));

    dff_async #(1) u_dffa (.clk(clk), .rst_n(rst_n), .en(en), .d(d_in), .q(dff_a_q));
    dff_sync  #(1) u_dffs (.clk(clk), .rst_n(rst_n), .en(en), .d(d_in), .q(dff_s_q));
    counter   #(8) u_cnt  (.clk(clk), .rst_n(rst_n), .en(en), .load(load), .up(up), .load_val(load_val), .count(cnt));
    shift_reg #(8) u_sr   (.clk(clk), .rst_n(rst_n), .mode(sr_mode), .ser_in(ser_in), .par_in(par_in), .q(sr_q));
    seq_detect_1011 u_det (.clk(clk), .rst_n(rst_n), .in(bit_in), .detected(detected));
endmodule
