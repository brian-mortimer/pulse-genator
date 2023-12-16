//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Simple 7-segment display driver for Digilent Nexys4 DDR
// Author: Karl Rinne
// Create Date: 27/05/2020
// Design Name: generic
// Revision: 1.1
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2001
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

`include "timing.v"

module display_7s
#(
    parameter           PRESCALER_RLD=99_999,      // Prescaler reload value, setting display digit active time
    parameter           PRESCALER_RLD_TURBOSIM=9,
    parameter           BLINK_RLD=499,              // Blink reload value, based on display digit active time
    parameter           BLINK_RLD_TURBOSIM=19
)
(
    input wire          clk,                // clock input (rising edge)
    input wire          reset,              // reset input (synchronous)
    input wire          turbosim,           // speeds up simulation
    input wire          en,                 // Enables display if 1
    input wire [63:0]   dis_data,           // Combined 64b display data with each display digit taking 8 bits.
                                            // MSB of each of these 8 bits represents decimal point (hardware decimal point is shown to the right of the display digit)
                                            // Depending on mode, the remaining 7 bits are either directly displayed (straight data mode)
                                            // or, if hex-mode is enabled for the display digit, bits [3:0] will be decoded and displayed in hex format
    input wire [7:0]    dis_mode,           // Mode for each display digit: 0: straight data mode. 1: hex decoder mode.
    input wire [7:0]    dis_blink,          // Blink enable for each display digit: 0: on. 1: blinking.
    input wire          negate_a,           // If set, negates outputs anodes (depending on external anode driver)
    output wire [7:0]   cathodes_n,         // Cathodes of 7-segment display arranged as {dp,g,f,e,d,c,b,a}. Active-low.
    output wire [7:0]   anodes,             // Anodes of 7-segment display, MSB is left-most digit.
                                            // If anodes are driven via pnp transistors, negation is required (pull negate_a to 1)
    output wire         blink               // Blinker output, toggling between 0 and 1 at blink frequency
);
`include "wordlength.v"

reg [wordlength(PRESCALER_RLD)-1:0] d7_prescaler;
wire[wordlength(PRESCALER_RLD)-1:0] d7_prescaler_rld;
wire                    d7_prescaler_zero;
reg [wordlength(BLINK_RLD)-1:0]     d7_blink_counter;
wire                    d7_blink_counter_zero;
reg                     d7_blink_bit;
reg [2:0]               d7_pointer;
wire [5:0]              d7_shifter_nob;
wire [63:0]             d7_dis_data_shifted;
wire [7:0]              d7_digit_data;
reg [6:0]               d7_hex_decoder;
wire [7:0]              d7_mode;
wire [7:0]              d7_blink;
wire                    d7_enable;
wire [7:0]              d7_anodes;

// ************************************************************************************************
// Display management and muxing
// ************************************************************************************************
assign d7_enable=en&(~reset);
assign d7_shifter_nob={d7_pointer,3'b000};
assign d7_dis_data_shifted=dis_data>>(d7_shifter_nob);
assign d7_digit_data=d7_dis_data_shifted[7:0];
assign d7_mode=dis_mode>>d7_pointer;
assign d7_blink=dis_blink>>d7_pointer;
assign d7_anodes=(d7_enable?(8'b0000_0001<<d7_pointer):8'b0000_0000);
assign anodes=(negate_a)? ~d7_anodes : d7_anodes;
assign cathodes_n=~(d7_enable&(~(d7_blink[0]&d7_blink_bit))?(d7_mode[0]?{d7_digit_data[7],d7_hex_decoder}:d7_digit_data):8'b0000_0000);
assign blink=d7_blink_bit;

// ************************************************************************************************
// Hex 4-bit to 7-segment decoder
// ************************************************************************************************
always @(*) begin
    case (d7_digit_data[3:0])
        4'd00:  d7_hex_decoder=7'b0111111;
        4'd01:  d7_hex_decoder=7'b0000110;
        4'd02:  d7_hex_decoder=7'b1011011;
        4'd03:  d7_hex_decoder=7'b1001111;
        4'd04:  d7_hex_decoder=7'b1100110;
        4'd05:  d7_hex_decoder=7'b1101101;
        4'd06:  d7_hex_decoder=7'b1111101;
        4'd07:  d7_hex_decoder=7'b0000111;
        4'd08:  d7_hex_decoder=7'b1111111;
        4'd09:  d7_hex_decoder=7'b1101111;
        4'd10:  d7_hex_decoder=7'b1110111;
        4'd11:  d7_hex_decoder=7'b1111100;
        4'd12:  d7_hex_decoder=7'b1011000;
        4'd13:  d7_hex_decoder=7'b1011110;
        4'd14:  d7_hex_decoder=7'b1111001;
        4'd15:  d7_hex_decoder=7'b1110001;
        default:    d7_hex_decoder=7'b0000000;
    endcase
end

// ************************************************************************************************
// Display timing prescaler
// ************************************************************************************************
always @ (posedge clk) begin
    if (~d7_enable) begin
        d7_prescaler<=0;
    end else begin
        if (d7_prescaler_zero) begin
            if (turbosim) begin
                d7_prescaler<=PRESCALER_RLD_TURBOSIM;
            end else begin
                d7_prescaler<=PRESCALER_RLD;
            end
        end else begin
            d7_prescaler<=d7_prescaler-1'b1;
        end
    end
end
assign d7_prescaler_zero=~(|d7_prescaler);

// ************************************************************************************************
// Display digit pointer
// ************************************************************************************************
always @ (posedge clk) begin
    if (~d7_enable) begin
        d7_pointer<=0;
    end else begin
        if (d7_prescaler_zero) begin
            d7_pointer<=d7_pointer+1'b1;
        end
    end
end

// ************************************************************************************************
// Blink counter
// ************************************************************************************************
always @ (posedge clk) begin
    if (~d7_enable) begin
        d7_blink_counter<=0;
        d7_blink_bit<=0;
    end else begin
        if (d7_prescaler_zero) begin
            if (d7_blink_counter_zero) begin
                d7_blink_bit<=~d7_blink_bit;
                if (turbosim) begin
                    d7_blink_counter<=BLINK_RLD_TURBOSIM;
                end else begin
                    d7_blink_counter<=BLINK_RLD;
                end
            end else begin
                d7_blink_counter<=d7_blink_counter-1'b1;
            end
        end
    end
end
assign d7_blink_counter_zero=~(|d7_blink_counter);

endmodule
