//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

`include "timing.v"

module signal_generator(
    input   wire            clk,
    input   wire            reset,
    input   wire [15:0]     tph,
    input   wire [15:0]     tpl,
    output  reg             signal_out,
    output  reg             signal_cycle
);

reg [11:0]                  tph_cycles;
reg [11:0]                  tpl_cycles;
reg [11:0]                  high_cycles;
reg [11:0]                  counter;

always @(posedge clk) begin
    if (reset) begin
        signal_out<=1;
        counter<=0;
        tph_cycles<=convert_to_cycles(tph);
        tpl_cycles<=convert_to_cycles(tpl);
        high_cycles<=10;
    end else begin
            if (counter < tph_cycles) begin
                if (counter < high_cycles) signal_cycle = 1; else signal_cycle = 0;
                // Signal is high
                signal_out <= 1;
                counter <= counter + 1;
            end else if (counter < tph_cycles + tpl_cycles-1) begin
                // Signal is low
                signal_out <= 0;
                counter <= counter + 1;
            end else begin
                // Reset counter
                counter <= 0;
                // Update cycles
                tph_cycles <= convert_to_cycles(tph);
                tpl_cycles <= convert_to_cycles(tpl);
            end
    end
end

function [11:0] convert_to_cycles(input [15:0] time_in_microseconds_format);
    reg [6:0]   first_digit;
    reg [7:0]   second_digit;
    reg [11:0]  time_in_microseconds;
    begin
        // Extract relevent values
        first_digit = time_in_microseconds_format[14:8];
        second_digit = time_in_microseconds_format[7:0];

        // Combine values ( note: 9.9 us is 99 here to simplify)
        time_in_microseconds = first_digit * 10 + second_digit;

        // Convert microseconds to clock cycles (because time_in_microseconds is 99 instead of 9.9, multiple by 10 instead of 100.)
        convert_to_cycles = time_in_microseconds * 10;
    end
endfunction

endmodule
