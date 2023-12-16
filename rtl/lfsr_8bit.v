//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////
`include "timing.v"

module lfsr_8bit(
    input  wire         clk,
    input  wire         reset,
    output reg          signal_out,
    output reg          signal_cycle
    );
    
    reg [7:0]           lfsr;
    wire                feedback;
    reg [7:0]           counter;
    
    assign feedback = ~(lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]);
    
    always @(posedge clk) begin
        if (reset) begin
            lfsr <= 8'b0000_0001;
            signal_out<=0;
            counter = 0;
        end else begin
            if (counter == 99) begin
                lfsr<={lfsr[6:0], feedback};
                signal_out<=lfsr[7];
                counter = 0;
            end else begin
                counter<=counter +1;
            end           
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            signal_cycle <= 0;
        end else begin
            if (lfsr == 8'b0000_0000) begin
                signal_cycle <= 1;
            end else begin
                signal_cycle <= 0;
            end
        end
    end
endmodule
