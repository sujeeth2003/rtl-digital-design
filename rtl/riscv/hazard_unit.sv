// Hazard handling for the 5-stage pipeline (IF ID EX MEM WB).
//
//  1. Data hazards, forwarding into EX:
//       fwd = 2'b01 : take the value from the instruction now in MEM (EX/MEM result)
//       fwd = 2'b10 : take the value from the instruction now in WB  (MEM/WB result)
//       fwd = 2'b00 : use the register-file value read in ID
//     MEM has priority over WB (it is the younger, i.e. more recent, producer).
//  2. Load-use hazard: a load's data only exists after MEM, so if the instruction in
//     ID needs the register the load in EX will write, stall IF/ID one cycle and
//     insert a bubble into EX (then the WB->EX forward supplies the data).
//  3. Control hazard: branches and jumps resolve in EX, so when one is taken the two
//     younger instructions in IF/ID and ID/EX are flushed (2-cycle penalty).
module hazard_unit (
    // consumer in EX
    input  logic [4:0] ex_rs1, ex_rs2,
    // producers
    input  logic [4:0] mem_rd, wb_rd,
    input  logic       mem_reg_write, wb_reg_write,
    output logic [1:0] fwd_a, fwd_b,
    // load-use detection (ID consumer vs. EX load)
    input  logic [4:0] id_rs1, id_rs2,
    input  logic       id_uses_rs1, id_uses_rs2,
    input  logic       ex_mem_read, ex_valid,
    input  logic [4:0] ex_rd,
    output logic       stall,
    // control hazard
    input  logic       ex_taken,
    output logic       flush
);
    always_comb begin
        fwd_a = 2'b00;
        if (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs1)      fwd_a = 2'b01;
        else if (wb_reg_write && wb_rd != 5'd0 && wb_rd == ex_rs1)    fwd_a = 2'b10;

        fwd_b = 2'b00;
        if (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs2)      fwd_b = 2'b01;
        else if (wb_reg_write && wb_rd != 5'd0 && wb_rd == ex_rs2)    fwd_b = 2'b10;
    end

    assign stall = ex_valid && ex_mem_read && ex_rd != 5'd0 &&
                   ((id_uses_rs1 && ex_rd == id_rs1) || (id_uses_rs2 && ex_rd == id_rs2));
    assign flush = ex_taken;
endmodule
