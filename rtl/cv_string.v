//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 15/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////
`include "timing.v"

module cv_string
    #(
        parameter MAX_PIXEL_H=1280,                     // max value of pixel counter
        parameter MAX_SCANLINES=625,  
        parameter CHAR_SPACE=16
    )
    (
        input wire                  clk,                // clock input (rising edge)
        input wire                  reset,              // reset input (synchronous)
        input wire                  en,                 // enable cv_control
        input wire                  clk_en_pixel,       // clk enable signal active pixel (one in every N clk cycles)
        input wire                  x_vis,              // x visible flag
        input wire [$clog2(MAX_PIXEL_H)-1:0] x_pos,     // current x position of display
        input wire [$clog2(MAX_SCANLINES)-1:0] y_pos,   // current y position of display
        input wire [$clog2(MAX_PIXEL_H)-1:0] start_text_x,    // placement of char (x)
        input wire [$clog2(MAX_SCANLINES)-1:0] start_text_y,  // placement of char (y)
        input wire [1:0]            text_lum_bg,        // char luminance (background)
        input wire [1:0]            text_lum_fg,        // char luminance (foreground)
        input wire [95:0]           text_in,            // char to be displayed (ASCII)
        output wire [1:0]           cv_lum                 // luminance output
    );
    
    wire [1:0] cv_lum_content0;
    wire [1:0] cv_lum_content1;
    wire [1:0] cv_lum_content2;
    wire [1:0] cv_lum_content3;
    wire [1:0] cv_lum_content4;
    wire [1:0] cv_lum_content5;
    wire [1:0] cv_lum_content6;
    wire [1:0] cv_lum_content7;
    wire [1:0] cv_lum_content8;
    wire [1:0] cv_lum_content9;
    wire [1:0] cv_lum_content10;
    wire [1:0] cv_lum_content11;

    // character rom, 2kB
    wire [10:0] chrom_addr0;
    wire [10:0] chrom_addr1;
    wire [10:0] chrom_addr2;
    wire [7:0] chrom_din0;
    wire [7:0] chrom_din1;
    wire [7:0] chrom_din2;

    // shared access to character rom
    wire [10:0] crom_addr0;
    wire [10:0] crom_addr1;
    wire [10:0] crom_addr2;
    wire [10:0] crom_addr3;
    wire [10:0] crom_addr4;
    wire [10:0] crom_addr5;
    wire [10:0] crom_addr6;
    wire [10:0] crom_addr7;
    wire [10:0] crom_addr8;
    wire [10:0] crom_addr9;
    wire [10:0] crom_addr10;
    wire [10:0] crom_addr11;
    wire [7:0] crom_din0;
    wire [7:0] crom_din1;
    wire [7:0] crom_din2;
    wire [7:0] crom_din3;
    wire [7:0] crom_din4;
    wire [7:0] crom_din5;
    wire [7:0] crom_din6;
    wire [7:0] crom_din7;
    wire [7:0] crom_din8;
    wire [7:0] crom_din9;
    wire [7:0] crom_din10;
    wire [7:0] crom_din11;
    wire crom_rq0;
    wire crom_rq1;
    wire crom_rq2;
    wire crom_rq3;
    wire crom_rq4;
    wire crom_rq5;
    wire crom_rq6;
    wire crom_rq7;
    wire crom_rq8;
    wire crom_rq9;
    wire crom_rq10;
    wire crom_rq11;
    
    // Combine luminance of all video content providers
    assign cv_lum[1:0]=(cv_lum_content0|cv_lum_content1|cv_lum_content2|cv_lum_content3|cv_lum_content4|cv_lum_content5|cv_lum_content6|cv_lum_content7|cv_lum_content8|cv_lum_content9|cv_lum_content10|cv_lum_content11);

    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char0
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (0*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*12)-1:(8*12)-8]),
        .crom_addr(crom_addr0),
        .crom_rq(crom_rq0),
        .crom_din(crom_din0),
        .lum(cv_lum_content0)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char1
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (1*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*11)-1:(8*11)-8]),
        .crom_addr(crom_addr1),
        .crom_rq(crom_rq1),
        .crom_din(crom_din1),
        .lum(cv_lum_content1)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char2
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (2*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*10)-1:(8*10)-8]),
        .crom_addr(crom_addr2),
        .crom_rq(crom_rq2),
        .crom_din(crom_din2),
        .lum(cv_lum_content2)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char3
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (3*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*9)-1:(8*9)-8]),
        .crom_addr(crom_addr3),
        .crom_rq(crom_rq3),
        .crom_din(crom_din3),
        .lum(cv_lum_content3)
    );
    // manage shared access to a single character rom
    cv_charrom_access cv_charrom_access0
    (
        .clk(clk),
        .reset(reset),
        .crom_addr(chrom_addr0),
        .crom_din(chrom_din0),
        .all_addr({crom_addr3, crom_addr2, crom_addr1, crom_addr0}),
        .all_rq({crom_rq3, crom_rq2, crom_rq1, crom_rq0}),
        .all_data({crom_din3,crom_din2,crom_din1,crom_din0})
    );
    // character rom (256 ASCII characters, legacy VGA-compliant, 8 lines of 8b/line(
    cv_charrom cv_charrom0
    (
        .clk(clk),
        .data(chrom_din0),
        .adr(chrom_addr0),
        .seln(1'b0),
        .rdn(1'b0)
    );
    
    
    
    
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char4
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (4*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*8)-1:(8*8)-8]),
        .crom_addr(crom_addr4),
        .crom_rq(crom_rq4),
        .crom_din(crom_din4),
        .lum(cv_lum_content4)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char5
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (5*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*7)-1:(8*7)-8]),
        .crom_addr(crom_addr5),
        .crom_rq(crom_rq5),
        .crom_din(crom_din5),
        .lum(cv_lum_content5)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char6
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (6*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*6)-1:(8*6)-8]),
        .crom_addr(crom_addr6),
        .crom_rq(crom_rq6),
        .crom_din(crom_din6),
        .lum(cv_lum_content6)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char7
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (7*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*5)-1:(8*5)-8]),
        .crom_addr(crom_addr7),
        .crom_rq(crom_rq7),
        .crom_din(crom_din7),
        .lum(cv_lum_content7)
    );
    // manage shared access to a single character rom
    cv_charrom_access cv_charrom_access1
    (
        .clk(clk),
        .reset(reset),
        .crom_addr(chrom_addr1),
        .crom_din(chrom_din1),
        .all_addr({crom_addr7, crom_addr6, crom_addr5, crom_addr4}),
        .all_rq({crom_rq7, crom_rq6, crom_rq5, crom_rq4}),
        .all_data({crom_din7,crom_din6,crom_din5,crom_din4})
    );
    // character rom (256 ASCII characters, legacy VGA-compliant, 8 lines of 8b/line(
    cv_charrom cv_charrom1
    (
        .clk(clk),
        .data(chrom_din1),
        .adr(chrom_addr1),
        .seln(1'b0),
        .rdn(1'b0)
    );
    
    
    
    
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char8
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (8*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*4)-1:(8*4)-8]),
        .crom_addr(crom_addr8),
        .crom_rq(crom_rq8),
        .crom_din(crom_din8),
        .lum(cv_lum_content8)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char9
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (9*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*3)-1:(8*3)-8]),
        .crom_addr(crom_addr9),
        .crom_rq(crom_rq9),
        .crom_din(crom_din9),
        .lum(cv_lum_content9)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char10
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (10*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*2)-1:(8*2)-8]),
        .crom_addr(crom_addr10),
        .crom_rq(crom_rq10),
        .crom_din(crom_din10),
        .lum(cv_lum_content10)
    );
    cv_char #( .NOF_TEXT_PIXELS(1) ) cv_char11
    (
        .clk(clk),
        .reset(reset),
        .en(en),
        .clk_en_pixel(clk_en_pixel),
        .x_vis(x_vis),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .text_x(start_text_x + (11*CHAR_SPACE)),
        .text_y(start_text_y),
        .text_lum_bg(text_lum_bg),
        .text_lum_fg(text_lum_fg),
        .char_in(text_in[(8*1)-1:(8*1)-8]),
        .crom_addr(crom_addr11),
        .crom_rq(crom_rq11),
        .crom_din(crom_din11),
        .lum(cv_lum_content11)
    );
    // manage shared access to a single character rom
    cv_charrom_access cv_charrom_access2
    (
        .clk(clk),
        .reset(reset),
        .crom_addr(chrom_addr2),
        .crom_din(chrom_din2),
        .all_addr({crom_addr11, crom_addr10, crom_addr9, crom_addr8}),
        .all_rq({crom_rq11, crom_rq10, crom_rq9, crom_rq8}),
        .all_data({crom_din11,crom_din10,crom_din9,crom_din8})
    );
    // character rom (256 ASCII characters, legacy VGA-compliant, 8 lines of 8b/line(
    cv_charrom cv_charrom2
    (
        .clk(clk),
        .data(chrom_din2),
        .adr(chrom_addr2),
        .seln(1'b0),
        .rdn(1'b0)
    );
    
    

endmodule
