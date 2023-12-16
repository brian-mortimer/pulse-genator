//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Debounce (for button and switches)
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

module debounce
#(
    parameter           DEBOUNCE_MAX=9      // integration counter for debounce, max value
                                            // debounce time is (DEBOUNCE_MAX+1)*f_en
)
(
    input wire          clk,                // clock input
    input wire          reset,              // reset input (synchronous)
    input wire          en,                 // counting enabled
    input wire          signal_in,          // raw input signal
    output reg          signal_debounced    // debounced output signal
);

wire        count_zero;
wire        count_max;

`include "wordlength.v"
reg [wordlength(DEBOUNCE_MAX)-1:0] counter;    // counter vector

always @ (posedge clk) begin
    if (reset) begin
        counter<=0; signal_debounced<=0;

    end
    else begin
        if(en) begin
            if (signal_in) begin
                if (count_max) begin
                    signal_debounced<=1;
                end else begin
                    counter<=counter+1;
                end
            end else begin
                if (count_zero) begin
                    signal_debounced<=0;
                end else begin
                    counter<=counter-1;
                end
            end
        end
    end
end
assign count_zero=(counter==0);
assign count_max=(counter==DEBOUNCE_MAX);

endmodule
