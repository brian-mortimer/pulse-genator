//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 FPGA Project (targeting Digilent Cmod A7-x5T)
// Author: Karl Rinne
// Design Name: Composite Video (cv). Char output ASCII, single character.
// Revision: 1.0 30/10/2021
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2005
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

// [20] http://www.batsocks.co.uk/readme/video_timing.htm

`include "timing.v"

module cv_char
#(
    parameter MAX_PIXEL_H=1280,                     // max value of pixel counter
    parameter MAX_SCANLINES=625,
    parameter NOF_TEXT_PIXELS=3                     // number of horizontal char pixels per display pixel.
                                                    // valid choices 0..3 (encoding 1..4). vertical height follows with 1 2 or 4.
)
(
    input wire                  clk,                // clock input (rising edge)
    input wire                  reset,              // reset input (synchronous)
    input wire                  en,                 // enable cv_control
    input wire                  clk_en_pixel,       // clk enable signal active pixel (one in every N clk cycles)
    input wire                  x_vis,              // x visible flag
    input wire [$clog2(MAX_PIXEL_H)-1:0] x_pos,     // current x position of display
    input wire [$clog2(MAX_SCANLINES)-1:0] y_pos,   // current y position of display
    input wire [$clog2(MAX_PIXEL_H)-1:0] text_x,    // placement of char (x)
    input wire [$clog2(MAX_SCANLINES)-1:0] text_y,  // placement of char (y)
    input wire [1:0]            text_lum_bg,        // char luminance (background)
    input wire [1:0]            text_lum_fg,        // char luminance (foreground)
    input wire [7:0]            char_in,            // char to be displayed (ASCII)
    output reg [10:0]           crom_addr,          // character rom, addr
    output reg                  crom_rq,            // character rom, request for data
    input wire [7:0]            crom_din,           // character rom, data in
    output wire [1:0]           lum                 // luminance output
);

localparam              CHAR_PX_Y_ASR=(NOF_TEXT_PIXELS==0)?0:( (NOF_TEXT_PIXELS==1)?1:2 );  // CHAR_PX_Y_ASR is 0, 1 or 2 for char heights 8, 16 or 32 pixels

// fsm_text
localparam              FSM_TEXT_S_WAIT4FIELD0=0;
localparam              FSM_TEXT_S_PREP=1;
localparam              FSM_TEXT_S_CHAR=2;
localparam              FSM_TEXT_S_WAIT4LINE=3;
localparam              FSM_TEXT_S_WAIT4FIELD1=4;
localparam              FSM_TEXT_S_RESET=7;         // make this state with largest number (determines width of state register)
reg [$clog2(FSM_TEXT_S_RESET)-1:0] fsm_text_state_next, fsm_text_state;

// video output register
reg [7:0] cv_out;
reg cv_out_load;
reg [1:0] cv_out_lum;
wire [7:0] cv_out_shifted;

// char to be displayed next
reg [7:0] char_next;
reg char_next_load;

// sample text_x and text_y after first hit
reg text_xy_sample;
reg [$clog2(MAX_PIXEL_H)-1:0] text_x_sampled;
reg [$clog2(MAX_SCANLINES)-1:0] text_y_sampled;

// character rom
reg crom_addr_load;

// character display active flag
reg char_active;
reg char_active_set;
reg char_active_clr;

// character pixel pointer (x)
reg [2:0] char_px_x;                          // character pixel pointer (7..0)
reg char_px_x_load;
reg char_px_x_dec;
wire char_px_x_zero;
wire char_px_x_char_load;

// character pixel prescaler (x)
reg [$clog2(NOF_TEXT_PIXELS+1)-1:0] char_px_x_prescaler;
wire char_px_x_prescaler_zero;

// character pixel pointer (y)
reg [5:0] char_px_y_ctr;                        // counter 0..33
wire [3:0] char_px_y;                           // character pixel pointer (0..7), stops at 8 or 9
reg char_px_y_load0;
reg char_px_y_load1;
reg char_px_y_inc2;
wire char_px_y_max;
wire char_px_y_field;                           // indicates whether we're in field 0 or 1

// prep counter (used during pre-fetch phase FSM_TEXT_S_PREP)
reg [2:0] prep_counter;
reg prep_counter_load;
wire prep_counter_zero;
wire prep_counter_char_load;
wire prep_counter_addr_load;

wire [$clog2(NOF_TEXT_PIXELS+1)+4:0] text_y_height;

// trigger conditions
wire text_x_trigger_on;
wire text_x_trigger_on_sampled;
wire text_y_trigger_on0;                        // direct hit
wire text_y_trigger_on1_sampled;                // hit y=1
wire new_field;                                 // start of a new field (of a display frame)

// trigger for x/y placement match
assign text_x_trigger_on=(x_pos==text_x);
assign text_x_trigger_on_sampled=(x_pos==text_x_sampled);
assign text_y_trigger_on0=(y_pos==text_y);
assign text_y_trigger_on1_sampled=(y_pos==text_y_sampled+1);
assign new_field=(y_pos==0)||(y_pos==1);

//////////////////////////////////////////////////////////////////////////////////
// manage video output register
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        cv_out<=0;
    end else begin
        if ( clk_en_pixel ) begin
            if ( cv_out_load ) begin
                cv_out<=crom_din;
            end
        end
    end
end
assign cv_out_shifted=cv_out>>char_px_x;

//////////////////////////////////////////////////////////////////////////////////
// manage video output register (2-bit luminance)
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        cv_out_lum<=0;
    end else begin
        if ( clk_en_pixel ) begin
            if ( char_active ) begin
                if ( cv_out_shifted[0] ) begin
                    cv_out_lum<=text_lum_fg;
                end else begin
                    cv_out_lum<=text_lum_bg;
                end
            end else begin
                cv_out_lum<=0;
            end
        end
    end
end
assign lum=cv_out_lum;

//////////////////////////////////////////////////////////////////////////////////
// manage sampled text_x and text_y positions
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        text_x_sampled<=0; text_y_sampled<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( text_xy_sample ) begin
                text_x_sampled<=text_x;
                text_y_sampled<=text_y;
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage prep counter
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        prep_counter<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( prep_counter_load ) begin
                prep_counter<=7;
            end else begin
                if ( ~prep_counter_zero ) begin
                    prep_counter<=prep_counter-1;
                end
            end
        end
    end
end
assign prep_counter_char_load=(prep_counter==7);
assign prep_counter_addr_load=(prep_counter==6);
assign prep_counter_zero=(prep_counter==0);

//////////////////////////////////////////////////////////////////////////////////
// manage character register (part select from text input string)
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        char_next<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( char_next_load ) begin
                char_next<=char_in;
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage character rom address
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        crom_addr<=0; crom_rq<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( crom_addr_load ) begin
                crom_addr<={char_next,char_px_y[2:0]};
            end
            crom_rq<=crom_addr_load;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage char display active flag
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        char_active<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( char_active_clr ) begin
                char_active<=0;
            end else begin
                if ( char_active_set ) begin
                    char_active<=1;
                end
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage char pixel pointer (x)
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        char_px_x<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( char_px_x_load ) begin
                char_px_x<=7;
            end else begin
                if ( char_px_x_dec) begin
                    if ( char_px_x_zero ) begin
                    end else begin
                        if ( char_px_x_prescaler_zero ) begin
                            char_px_x<=char_px_x-1;
                        end
                    end
                end
            end
        end
    end
end
assign char_px_x_char_load=(char_px_x==7);
assign char_px_x_addr_load=(char_px_x==6);
assign char_px_x_zero=(char_px_x==0);

//////////////////////////////////////////////////////////////////////////////////
// manage char pixel prescaler (x)
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        char_px_x_prescaler<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( char_px_x_load ) begin
                char_px_x_prescaler<=NOF_TEXT_PIXELS;
            end else begin
                if ( char_px_x_prescaler_zero ) begin
                    char_px_x_prescaler<=NOF_TEXT_PIXELS;
                end else begin
                    char_px_x_prescaler<=char_px_x_prescaler-1;
                end
            end
        end
    end
end
assign char_px_x_prescaler_zero=(char_px_x_prescaler==0);

//////////////////////////////////////////////////////////////////////////////////
// manage char pixel pointer counter, and derive pixel pointer (y)
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~en) ) begin
        char_px_y_ctr<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( char_px_y_load0 ) begin
                char_px_y_ctr<=0;
            end else begin
                if ( char_px_y_load1 ) begin
                    char_px_y_ctr<=1;
                end else begin
                    if ( char_px_y_inc2 ) begin
                        char_px_y_ctr<=char_px_y_ctr+2;
                    end
                end
            end
        end
    end
end
assign char_px_y=char_px_y_ctr>>CHAR_PX_Y_ASR;
assign char_px_y_max=(char_px_y==8)||(char_px_y==9);
assign char_px_y_field=char_px_y_ctr[0];

//////////////////////////////////////////////////////////////////////////////////
// FSM text
//////////////////////////////////////////////////////////////////////////////////
// Management of state register:
always @(posedge clk) begin
    if (reset || (~en) ) begin
        fsm_text_state<=FSM_TEXT_S_RESET;
    end else begin
        if ( clk_en_pixel ) begin
            fsm_text_state<=fsm_text_state_next;
        end
    end
end
// Next-state and output logic. Combinational.
always @(*) begin
    fsm_text_state_next=fsm_text_state;
    text_xy_sample=0;
    prep_counter_load=0;
    crom_addr_load=0;
    char_next_load=0;
    char_px_x_load=0; char_px_x_dec=0;
    char_px_y_load0=0; char_px_y_load1=0; char_px_y_inc2=0;
    char_active_set=0; char_active_clr=0;
    cv_out_load=0;
    case ( fsm_text_state )
        FSM_TEXT_S_WAIT4FIELD0: begin
            if ( text_x_trigger_on && text_y_trigger_on0 ) begin
                text_xy_sample=1;
                fsm_text_state_next=FSM_TEXT_S_PREP;
                prep_counter_load=1; char_px_y_load0=1;
            end
        end
        FSM_TEXT_S_PREP: begin
            if ( prep_counter_char_load ) begin
                char_next_load=1;
            end
            if ( prep_counter_addr_load ) begin
                crom_addr_load=1;
            end
            if ( prep_counter_zero ) begin
                char_active_set=1; char_px_x_load=1; cv_out_load=1;
                fsm_text_state_next=FSM_TEXT_S_CHAR;
            end
        end
        FSM_TEXT_S_CHAR: begin
            char_px_x_dec=1;
            if ( x_vis ) begin
                if ( char_px_x_zero && char_px_x_prescaler_zero ) begin
                    char_px_y_inc2=1; char_active_clr=1;
                    fsm_text_state_next=FSM_TEXT_S_WAIT4LINE;
                end
            end else begin
                char_px_y_inc2=1; char_active_clr=1;
                fsm_text_state_next=FSM_TEXT_S_WAIT4LINE;
            end
        end
        FSM_TEXT_S_WAIT4LINE: begin
            if ( char_px_y_max || new_field ) begin
                if ( char_px_y_field ) begin
                    fsm_text_state_next=FSM_TEXT_S_WAIT4FIELD0;
                end else begin
                    fsm_text_state_next=FSM_TEXT_S_WAIT4FIELD1;
                end
            end else begin
                if ( text_x_trigger_on_sampled ) begin
                    fsm_text_state_next=FSM_TEXT_S_PREP;
                    prep_counter_load=1;
                    char_px_x_load=1;
                end
            end
        end
        FSM_TEXT_S_WAIT4FIELD1: begin
            if ( text_x_trigger_on_sampled && text_y_trigger_on1_sampled ) begin
                fsm_text_state_next=FSM_TEXT_S_PREP;
                prep_counter_load=1; char_px_x_load=1; char_px_y_load1=1;
            end
        end
        default: begin
            // reset, and recovery from unexpected states
            fsm_text_state_next=FSM_TEXT_S_WAIT4FIELD0;
        end
    endcase
end
endmodule
