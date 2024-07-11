// Asynchronous (dual-clock) FIFO, Gray-code pointer design (after Cummings, SNUG 2002).
//  * write and read pointers are Gray coded, so only ONE bit changes per increment;
//    a synchronizer that samples mid-change sees either the old or the new value, never garbage
//  * each pointer is synchronized into the other domain through a 2-flop synchronizer
//  * full  is computed in the write domain from the synchronized read pointer
//  * empty is computed in the read  domain from the synchronized write pointer
//  * flags are conservative: they may lag reality by a few cycles (full a bit late to clear,
//    empty a bit late to clear) but can never claim room/data that is not there
