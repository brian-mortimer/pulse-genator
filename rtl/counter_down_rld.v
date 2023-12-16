//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Simple down counter, with reload instruction input
// Author: Karl Rinne
// Create Date: 27/05/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2001
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

`include "timing.v"

module counter_down_rld
#(
    parameter           COUNT_MAX=19,       // counter starts counting down from this value towards zero. periodically.
                                            // after reaching zero, counter reloads COUNT_MAX.
                                            // the counter has thus (COUNT_MAX+1) distinct states, including value 0.
    parameter           COUNT_MAX_TURBOSIM=4
)
(
    input wire          clk,                // clock input
    input wire          reset,              // reset input (synchronous)
    input wire          turbosim,           // speeds up simulation
    input wire          rld,                // reload input
    output reg          underflow           // asserts for one clock cycle when counter value reaches value 0
);

wire         count_zero;

reg [wordlength(COUNT_MAX)-1:0] counter;    // counter vector

always @ (posedge clk) begin
    if (reset) begin
        counter<=COUNT_MAX_TURBOSIM; underflow<=0;
    end else begin
        underflow<=count_zero;
        if (rld|count_zero) begin
            if (turbosim) begin
                counter<=COUNT_MAX_TURBOSIM;
            end else begin
                counter<=COUNT_MAX;
            end
        end
        else begin
            counter<=counter-1'b1;
        end
    end
end
assign count_zero=(counter==0);

`include "wordlength.v"

endmodule
