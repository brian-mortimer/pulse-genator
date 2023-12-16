//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

`include "timing.v"

module time_pulse_control
(
    input wire                  clk,
    input wire                  reset,
    input wire [15:0]           in_tph,
    input wire [15:0]           in_tpl,
    input wire [15:0]           in_temp_tph,
    input wire [15:0]           in_temp_tpl,
    input wire                  tp_edit_enable,
    input wire [2:0]            tp_selected,
    input wire                  tp_adj,
    input wire                  tp_temp_sync,
    output reg [15:0]           out_tph,
    output reg [15:0]           out_tpl
);
    
    reg [3:0]                   temp_val;
    
    reg [15:0]                  next_tph;
    reg [15:0]                  next_tpl;
    
    
    always @(posedge clk) begin
        if(reset) begin
            out_tph<={1'b1,7'h2, 8'h0};
            out_tpl<={1'b1,7'h8, 8'h0};
        end else begin
            out_tph<=next_tph;
            out_tpl<=next_tpl;
        end
    end
    
    
    always @(*) begin
        if(reset) begin
            next_tph<={1'b1,7'h2, 8'h0};
            next_tpl<={1'b1,7'h8, 8'h0};
        end else begin
            next_tph=in_temp_tph;
            next_tpl=in_temp_tpl;
            
            
            
            if(tp_edit_enable==1'b1) begin
                // Get the input value
                case(tp_selected)
                    0: temp_val = in_temp_tph[11:8];
                    1: temp_val = in_temp_tph[3:0];
                    2: temp_val = in_temp_tpl[11:8];
                    3: temp_val = in_temp_tpl[3:0];
                endcase
                
                if (tp_adj == 1'b1) begin
                    // attempt to increment by 1
                    if (temp_val < 9) temp_val=temp_val+1;
                    else temp_val=0;
                end else begin
                    // attempt to decrement by 1
                    if (temp_val > 0) temp_val=temp_val-1;
                    else temp_val=9;
                end
                
                // Update the output values.
                case(tp_selected)
                    0: next_tph={1'b1, 3'b0, temp_val, in_temp_tph[7:0]};
                    1: next_tph={1'b1, in_temp_tph[14:8], 4'b0, temp_val};
                    2: next_tpl={1'b1, 3'b0, temp_val, in_temp_tpl[7:0]};
                    3: next_tpl={1'b1, in_temp_tpl[14:8], 4'b0, temp_val};
                endcase
                
                // Ensure both tph and tpl are not zero.
                if (next_tph=={1'b1, 15'b0} & next_tpl == {1'b1, 15'b0}) begin
                    next_tph=in_temp_tph;
                    next_tpl=in_temp_tpl;
                end
            end
            
            if (tp_temp_sync) begin
                next_tph=in_tph;
                next_tpl=in_tpl;
            end
        end
    end
    
 endmodule

