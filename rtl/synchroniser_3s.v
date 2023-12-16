//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Synchroniser (3-stage)
// Author: Karl Rinne
// Create Date: 31/05/2020
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

module synchroniser_3s
(
    input wire          clk,                // clock input
    input wire          reset,              // reset input (synchronous)
    input wire          en,                 // enable signal
    input wire          in,                 // raw input signal
    output wire         out                 // synchronised output signal                 
);

reg [2:0]               sr;

always @ (posedge clk) begin
    if (reset) begin
        sr<=0;
    end
    else begin
        if (en) begin
            sr<={sr[1:0],in};               // left-shift in
        end
    end
end
assign out=sr[2];

endmodule
