//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 15/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] cv_core.v test02, Karle Rinne


`include "timing.v"

module cv_core
#(
    parameter CLKS_PER_PIXEL=5,
    parameter MAX_PIXEL_H=1280,
    parameter MAX_SCANLINES=625
)
(
    input wire                  clk,                // clock input (rising edge)
    input wire                  reset,              // reset input (synchronous)
    input wire [7:0]            cv_ctrl,
    input wire  [15:0]          tph,
    input wire  [15:0]          tpl,
    input wire                  prbs_en,
    output wire [2:0]           cv_lum,             // composite video luminance
    output wire                 cv_chrom,           // composite video chrominance (not currently used)
    output reg                  cv_sync,            // composite video sync (assumes open-drain output)
    output wire                 cv_sync_h,          // composite video debug/measurement
    output wire                 cv_sync_v           // composite video debug/measurement
);

    wire cv_en;                                     // enable composite video
    wire cv_bias;

    wire clk_en_pixel;                              // clk enable signal active pixel (one in every N clk cycles)
    wire x_vis;
    wire [$clog2(MAX_PIXEL_H)-1:0] x_pos;           // x position
    wire [$clog2(MAX_SCANLINES)-1:0] y_pos;         // y position

    wire cv_sync_pre;
    wire cv_sync_main;
    wire cv_sync_post;

    reg  [1:0] cv_lum_mask;
    wire [1:0] cv_lum_content0;
    wire [1:0] cv_lum_content1;
    wire [1:0] cv_lum_content2;
    wire [1:0] cv_lum_content3;
    wire [1:0] cv_lum_content4;
    wire [1:0] cv_lum_content5;
    wire [1:0] cv_lum_content6;
    wire [1:0] cv_lum_content7;
    wire [1:0] cv_lum_content8;
    
    reg [1:0] pm_brightness;
    reg [1:0] prbs_brightness;
    reg [7:0] tph_1;
    reg [7:0] tph_2;
    reg [7:0] tpl_1;
    reg [7:0] tpl_2;


    // Handle control input
    assign cv_en=cv_ctrl[0];
    assign cv_bias=cv_ctrl[1];       // enables CV bias (pulling cv_lum[2] high

    // Manage composite sync
    always @(*) begin
        if ( reset | (~cv_en) ) begin
            cv_sync=1; cv_lum_mask=2'b00;
        end else begin
            casex ( {cv_sync_pre,cv_sync_main,cv_sync_post} )
                3'b1xx: begin
                    cv_sync=1; cv_lum_mask=2'b00;
                end
                3'b01x: begin
                    cv_sync=0; cv_lum_mask=2'b00;
                end
                3'b001: begin
                    cv_sync=1; cv_lum_mask=2'b00;
                end
                default: begin
                    cv_sync=1; cv_lum_mask=2'b11;
                end
            endcase
        end
    end

    // Manage composite luminance (bias)
    assign cv_lum[2]=cv_bias;

    // Manage composite chrominance (not used, tied low)
    assign cv_chrom=0;

    // Instantiate composite video (central control and timing)
    cv_control #( .CLKS_PER_PIXEL(CLKS_PER_PIXEL) ) cv_control
    (
        .clk(clk),
        .reset(reset),
        .cv_en(cv_en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .cv_sync_pre(cv_sync_pre),
        .cv_sync_main(cv_sync_main),
        .cv_sync_post(cv_sync_post),
        .cv_sync_h(cv_sync_h),
        .cv_sync_v(cv_sync_v)
    );

    // Combine luminance of all video content providers
    assign cv_lum[1:0]=(cv_lum_content0|cv_lum_content1|cv_lum_content2|cv_lum_content3|cv_lum_content4|cv_lum_content5|cv_lum_content6|cv_lum_content7|cv_lum_content8) & cv_lum_mask;
    
    always @(*) begin
        if( prbs_en ) begin
            pm_brightness = 2'd1; prbs_brightness = 2'd3; 
        end else begin 
            pm_brightness = 2'd3; prbs_brightness = 2'd1; 
        end
        tph_1 = tph[14:8] +8'h30;
        tph_2 = tph[7:0] +8'h30;
        tpl_1 = tpl[14:8] +8'h30;
        tpl_2 = tpl[7:0] +8'h30;
    end
    
    cv_string cv_string0
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd100),
        .text_lum_bg(2'd0),
        .text_lum_fg(pm_brightness),
        .text_in({"T", "P", "H", "=",tph_1, ".", tph_2, "u", "s", "", "", ""}),
        .cv_lum(cv_lum_content0)
    );
    
    cv_string cv_string1
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd120),
        .text_lum_bg(2'd0),
        .text_lum_fg(pm_brightness),
        .text_in({"T", "P", "L", "=",tpl_1, ".", tpl_2, "u", "s", "", "", ""}),
        .cv_lum(cv_lum_content1)
    );
    
    cv_string cv_string2
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd150),
        .text_lum_bg(2'd0),
        .text_lum_fg(prbs_brightness),
        .text_in({"P", "R", "B", "S","_", "M", "O", "D", "E", ":", " ", "1"}),
        .cv_lum(cv_lum_content2)
    );
    cv_string cv_string7
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd308),
        .start_text_y(10'd150),
        .text_lum_bg(2'd0),
        .text_lum_fg(prbs_brightness),
        .text_in({"M", "b", "/", "s"," ", "8", "B", "-", "L", "F", "S", "R"}),
        .cv_lum(cv_lum_content7)
    );
    cv_string cv_string8
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd516),
        .start_text_y(10'd150),
        .text_lum_bg(2'd0),
        .text_lum_fg(prbs_brightness),
        .text_in({"T", "a", "p", "s",":", "8", ",", "6", ",", "5", ",", "4"}),
        .cv_lum(cv_lum_content8)
    );
    
    
    cv_string cv_string3
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd500),
        .text_lum_bg(2'd0),
        .text_lum_fg(2'd3),
        .text_in({"L", "M", "1" ,"1", "8", "-", "E", "E", "6", "6","2", "1"}),
        .cv_lum(cv_lum_content3)
    );
    
    cv_string cv_string4
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd530),
        .text_lum_bg(2'd0),
        .text_lum_fg(2'd3),
        .text_in({"B", "r", "i" ,"a", "n", " ", "M", "o", "r", "t","i", "m"}),
        .cv_lum(cv_lum_content4)
    );
    cv_string cv_string5
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd292),
        .start_text_y(10'd530),
        .text_lum_bg(2'd0),
        .text_lum_fg(2'd3),
        .text_in({"e", "r", "(", "2" ,"0", "2", "5", "8", "7", "6", "3",")"}),
        .cv_lum(cv_lum_content5)
    );
    cv_string cv_string6
    (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .start_text_x(10'd100),
        .start_text_y(10'd470),
        .text_lum_bg(2'd0),
        .text_lum_fg(2'd3),
        .text_in({"P", "g", "0", "2" ,"-", "2", "0", "2", "3", "", "",""}),
        .cv_lum(cv_lum_content6)
    );
endmodule
