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
