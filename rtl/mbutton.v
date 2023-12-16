//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 FPGA Project (targeting Digilent Cmod A7-x5T)
// Author: Karl Rinne
// Design Name: muxed-pushbutton input
// Revision: 1.0 26/07/2021
//////////////////////////////////////////////////////////////////////////////////

// Description and notes
// Input pbin is sampled at the rising edge of respective muxin signal, e.g.
//  rising edge of muxin[1] samples pbin and ultimately sets button[0] (after debounce)
//  rising edge of muxin[6] samples pbin and ultimately sets button[5] (after debounce)
//  rising edge of muxin[0] samples pbin and ultimately sets button[MUX_NOB-1] (after debounce)
// All pushbutton input signals (muxin, pbin) are synchronised.

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2005
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

`include "timing.v"

module mbutton
#(
    parameter MUX_NOB=6
)
(
    input wire                  clk,                // clock input (rising edge)
    input wire                  reset,              // reset input (synchronous)
    input wire [MUX_NOB-1:0]    muxin,              // mux drive lines (active high, one-hot)
    input wire                  pbin,               // muxed button, return line
    output wire [MUX_NOB-1:0]   buttons             // demuxed button vector, debounced
);

reg [2:0]   pbin_s;                                 // synchroniser for pushbutton (3-stage)
wire        pbin_sf;                                // pbin, synchroniser, filtered (if applicable)

reg [MUX_NOB-1:0]   muxin_s0, muxin_s1;
wire [MUX_NOB-1:0]  muxin_posedge;
reg [MUX_NOB-1:0]   muxin_posedge_s;

reg sample_pbin;
reg sample_buttons;

reg [MUX_NOB-1:0]   buttons_s0, buttons_s1;
wire [MUX_NOB-1:0]  buttons_debounced_set;
wire [MUX_NOB-1:0]  buttons_debounced_clr;
reg [MUX_NOB-1:0]   buttons_debounced;

integer i;

// ************************************************************************************************
// synchroniser for pbin, mux lines
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        pbin_s<=0; muxin_s1<=0; muxin_s0<=0;
    end else begin
        pbin_s<={pbin_s[1:0],pbin};
        muxin_s1<=muxin_s0; muxin_s0<=muxin;
    end
end
// edge detection mux lines
assign muxin_posedge=(~muxin_s1) & muxin_s0;    // detect positive edges (s1 bits are zero, and s0 bits are one)

// pbin signal (synchronised, other than that no actual filter in place)
assign pbin_sf=pbin_s[2];

// ************************************************************************************************
// generate sample signals
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        sample_pbin<=0; sample_buttons<=0;
    end else begin
        muxin_posedge_s<=muxin_posedge;
        sample_pbin<=|muxin_posedge;
        sample_buttons<=muxin_posedge_s[0];
    end
end

// ************************************************************************************************
// sample pbin_sf, and set/clear corresponding bit in buttons_s0
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        buttons_s0<=0; buttons_s1<=0;
    end else begin
        if ( sample_pbin ) begin
            if ( pbin_sf ) begin
                // button pressed, set corresponding bit
                buttons_s0<=buttons_s0|muxin_posedge_s;
            end else begin
                // button not pressed, clear corresponding bit
                buttons_s0<=buttons_s0&(~muxin_posedge_s);
            end
        end
        if ( sample_buttons ) begin
            buttons_s1<=buttons_s0;
        end
    end
end
assign buttons_debounced_set=  buttons_s0  &   buttons_s1;
assign buttons_debounced_clr=(~buttons_s0) & (~buttons_s1);

// ************************************************************************************************
// produce debounced buttons
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        buttons_debounced<=0;
    end else begin
        for (i=0; i<MUX_NOB ; i=i+1) begin
            if ( buttons_debounced_set[i] ) begin
                buttons_debounced[i]=1'b1;
            end else begin
                if (  buttons_debounced_clr[i] ) begin
                    buttons_debounced[i]=1'b0;
                end
            end
        end
    end
end

// ************************************************************************************************
// assign output
// ************************************************************************************************
assign buttons={buttons_debounced[0],buttons_debounced[MUX_NOB-1:1]};

endmodule
