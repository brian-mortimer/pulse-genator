//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: 8-channel input mux for 7-segment display
// Author: Karl Rinne
// Create Date: 30/05/2020
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

module display_7s_mux
(
    input wire [79:0]   dis_content0,
    input wire [79:0]   dis_content1,
    input wire [79:0]   dis_content2,
    input wire [79:0]   dis_content3,
    input wire [79:0]   dis_content4,
    input wire [79:0]   dis_content5,
    input wire [79:0]   dis_content6,
    input wire [79:0]   dis_content7,
    output reg [79:0]   dis_data,
    input wire [3:0]    sel
);

always @(*) begin
    case (sel)
        0: dis_data=dis_content0;
        1: dis_data=dis_content1;
        2: dis_data=dis_content2;
        3: dis_data=dis_content3;
        4: dis_data=dis_content4;
        5: dis_data=dis_content5;
        6: dis_data=dis_content6;
        7: dis_data=dis_content7;
        default: dis_data=dis_content0;
    endcase
end

endmodule
