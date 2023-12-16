//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 FPGA Project (targeting Digilent Cmod A7-x5T)
// Author: Karl Rinne
// Design Name: Composite Video (cv). Control
// Revision: 1.0 28/07/2021
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2005
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

// [20] http://www.batsocks.co.uk/readme/video_timing.htm

`include "timing.v"

module cv_control
#(
    parameter CLKS_PER_PIXEL=5,
    parameter MAX_PIXEL_H=1280,                     // max value of pixel counter
    parameter MAX_SCANLINES=625,
    // horizontal sync section
    parameter SYNC_DUR_H_PRE=1650/50,               // 1.65us as per [20]
    parameter SYNC_DUR_H_MAIN=4700/50,              // 4.7us as per [20]
    parameter SYNC_DUR_H_POST=5700/50,              // 5.7us as per [20]
    // vertical broad sync section
    parameter SYNC_DUR_V_PRE=50/50,                 // skip
    parameter SYNC_DUR_V_MAIN=27300/50,             // 32us-4.7us as per [20]
    parameter SYNC_DUR_V_POST=4650/50,              // 4.7us as per [20]
    // vertical short sync section
    parameter SYNC_DUR_VS_PRE=50/50,                // skip
    parameter SYNC_DUR_VS_MAIN=2350/50,             // 2.35us as per [20]
    parameter SYNC_DUR_VS_POST=29650/50             // 32us-2.35us as per [20]
)
(
    input wire                  clk,                // clock input (rising edge)
    input wire                  reset,              // reset input (synchronous)
    input wire                  cv_en,              // enable cv_control
    output wire                 clk_en_pixel,       // clk enable signal active pixel (one in every N clk cycles)
    output reg                  x_vis,              // x visible flag
    output reg [$clog2(MAX_PIXEL_H)-1:0] x_pos,     // x position
    output reg [$clog2(MAX_SCANLINES)-1:0] y_pos,   // y position
    output reg                  cv_sync_pre,        // sync (front porch)
    output reg                  cv_sync_main,       // sync (main period)
    output reg                  cv_sync_post,       // sync (back porch)
    output wire                 cv_sync_h,          // sync horizontal (for debug/measurement)
    output wire                 cv_sync_v           // sync vertical (for debug/measurement)
);

// scanline trigger points
localparam              PIXEL_H_HALF=MAX_PIXEL_H/2;
localparam              PIXEL_H_NEAREND=MAX_PIXEL_H-SYNC_DUR_H_PRE;

// fsm_frame states
localparam              FSM_FRAME_S_WAIT=0;
localparam              FSM_FRAME_S_F0_VSYNC_MAIN=1;    // field 0 (even), vertical sync (broad sync region)
localparam              FSM_FRAME_S_F0_VSYNC_POST0=2;   // field 0 (even), vertical sync (short sync region, color burst)
localparam              FSM_FRAME_S_F0_VSYNC_POST1=11;  // field 0 (even), vertical sync (short sync region, color burst)
localparam              FSM_FRAME_S_F0_NV=3;            // field 0 (even), non-visible
localparam              FSM_FRAME_S_F0_V=4;             // field 0 (even), visible
localparam              FSM_FRAME_S_F1_VSYNC_PRE0=13;   // field 1 (odd), vertical sync (short sync region)
localparam              FSM_FRAME_S_F1_VSYNC_PRE1=5;    // field 1 (odd), vertical sync (short sync region)
localparam              FSM_FRAME_S_F1_VSYNC_MAIN=6;    // field 1 (odd), vertical sync (broad sync region)
localparam              FSM_FRAME_S_F1_VSYNC_POST0=7;   // field 1 (odd), vertical sync (short sync region, color burst)
localparam              FSM_FRAME_S_F1_VSYNC_POST1=12;  // field 1 (odd), vertical sync (short sync region, color burst)
localparam              FSM_FRAME_S_F1_NV=8;            // field 1 (odd), non-visible
localparam              FSM_FRAME_S_F1_V=9;             // field 1 (odd), visible
localparam              FSM_FRAME_S_F0_VSYNC_PRE0=14;   // field 0 (even), vertical sync (short sync region)
localparam              FSM_FRAME_S_F0_VSYNC_PRE1=10;   // field 0 (even), vertical sync (short sync region)
localparam              FSM_FRAME_S_RESET=15;           // make this state with largest number (determines width of state register)
reg [$clog2(FSM_FRAME_S_RESET)-1:0] fsm_frame_state_next, fsm_frame_state;

// fsm_sync states
localparam              FSM_SYNC_S_WAIT=0;
localparam              FSM_SYNC_S_PRE=1;
localparam              FSM_SYNC_S_MAIN=2;
localparam              FSM_SYNC_S_POST=3;
localparam              FSM_SYNC_S_RESET=7;         // make this state with largest number (determines width of state register)
reg [$clog2(FSM_SYNC_S_RESET)-1:0] fsm_sync_state_next, fsm_sync_state;

reg [$clog2(CLKS_PER_PIXEL)-1:0] clk_prescaler;
reg [$clog2(MAX_PIXEL_H)-1:0] cnt_pixel_h;
wire trig_scanline_half_m1;
wire trig_scanline_half;
wire trig_scanline_nearend;
wire trig_scanline_clamp_m1;
wire trig_scanline_clamp;

reg [$clog2(MAX_SCANLINES)-1:0] scanline_cnt;
wire scanline_cnt_max;
reg [$clog2(MAX_SCANLINES)-1:0] hsl_cnt;
wire hsl_cnt_zero;
reg hsl_cnt_load;
reg [$clog2(MAX_SCANLINES)-1:0] hsl_cnt_load_v;

reg sync_trig;
reg sync_load;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_dur_pre;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_dur_main;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_dur_post;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_loadvalue_pre;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_loadvalue_main;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_loadvalue_post;

reg [$clog2(MAX_PIXEL_H)-1:0] sync_counter;
reg [$clog2(MAX_PIXEL_H)-1:0] sync_counter_value;
reg sync_counter_load;
wire sync_counter_zero;

reg x_vis_trig_on;      // x visibility trigger on
reg x_vis_trig_off;     // x visibility trigger off
reg x_pos_clr;
reg x_pos_cnt;
reg x_pos_cnt_on;
reg x_pos_cnt_off;

//////////////////////////////////////////////////////////////////////////////////
// pixel clk prescaler
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~cv_en) || clk_en_pixel ) begin
        clk_prescaler<=(CLKS_PER_PIXEL-1);
    end
    else begin
        clk_prescaler<=clk_prescaler-1;
    end
end
assign clk_en_pixel=(clk_prescaler==0);

//////////////////////////////////////////////////////////////////////////////////
// pixel counter (upcounter, clamps at MAX_PIXEL_H-1) also delivering relevant trigger points
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~cv_en) ) begin
        cnt_pixel_h<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if (  (~trig_scanline_clamp) ) begin
                cnt_pixel_h<=cnt_pixel_h+1;
            end else begin
                cnt_pixel_h<=0;
            end
        end
    end
end
assign trig_scanline_half_m1=( cnt_pixel_h==(PIXEL_H_HALF-3) );
assign trig_scanline_half=( cnt_pixel_h==(PIXEL_H_HALF-1) );
assign trig_scanline_nearend=( cnt_pixel_h==(PIXEL_H_NEAREND-2) );
assign trig_scanline_clamp_m1=( cnt_pixel_h==(MAX_PIXEL_H-3) );
assign trig_scanline_clamp=( cnt_pixel_h==(MAX_PIXEL_H-1) );

//////////////////////////////////////////////////////////////////////////////////
// scanline counter
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~cv_en) ) begin
        scanline_cnt<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( trig_scanline_clamp ) begin
                if ( scanline_cnt_max ) begin
                    scanline_cnt<=0;
                end else begin
                    scanline_cnt<=scanline_cnt+1;
                end
            end
        end
    end
end
assign scanline_cnt_max=(scanline_cnt==(MAX_SCANLINES-1));

//////////////////////////////////////////////////////////////////////////////////
// half scanline counter, controlled by and assisting frame state machine
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~cv_en) ) begin
        hsl_cnt<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( hsl_cnt_load ) begin
                hsl_cnt<=hsl_cnt_load_v;
            end else begin
                if ( (~hsl_cnt_zero) && (trig_scanline_half_m1 || trig_scanline_clamp_m1) ) begin
                    hsl_cnt<=hsl_cnt-1;
                end
            end
        end
    end
end
assign hsl_cnt_zero=( hsl_cnt==0 );

//////////////////////////////////////////////////////////////////////////////////
// Sync trigger management
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset || (~cv_en) ) begin
        sync_dur_pre<=0; sync_dur_main<=0; sync_dur_post<=0; sync_trig<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            case (fsm_frame_state)
                FSM_FRAME_S_F0_NV,
                FSM_FRAME_S_F0_V,
                FSM_FRAME_S_F1_NV,
                FSM_FRAME_S_F1_V:
                begin
                    if ( trig_scanline_nearend ) begin
                        sync_dur_pre<=(SYNC_DUR_H_PRE-1); sync_dur_main<=(SYNC_DUR_H_MAIN-1); sync_dur_post<=(SYNC_DUR_H_POST-1); sync_trig<=1;
                    end else begin
                        sync_trig<=0;
                    end
                end
                FSM_FRAME_S_F0_VSYNC_MAIN,
                FSM_FRAME_S_F1_VSYNC_MAIN:
                begin
                    if ( trig_scanline_half || trig_scanline_clamp ) begin
                        sync_dur_pre<=(SYNC_DUR_V_PRE-1); sync_dur_main<=(SYNC_DUR_V_MAIN-1); sync_dur_post<=(SYNC_DUR_V_POST-1); sync_trig<=1;
                    end else begin
                        sync_trig<=0;
                    end
                end
                FSM_FRAME_S_F0_VSYNC_POST0,
                FSM_FRAME_S_F1_VSYNC_PRE1,
                FSM_FRAME_S_F1_VSYNC_POST0,
                FSM_FRAME_S_F1_VSYNC_POST1,
                FSM_FRAME_S_F0_VSYNC_PRE1:
                begin
                    if ( trig_scanline_half || trig_scanline_clamp ) begin
                        sync_dur_pre<=(SYNC_DUR_VS_PRE-1); sync_dur_main<=(SYNC_DUR_VS_MAIN-1); sync_dur_post<=(SYNC_DUR_VS_POST-1); sync_trig<=1;
                    end else begin
                        sync_trig<=0;
                    end
                end
                FSM_FRAME_S_F0_VSYNC_POST1:
                begin
                    if ( trig_scanline_half ) begin
                        sync_dur_pre<=(SYNC_DUR_VS_PRE-1); sync_dur_main<=(SYNC_DUR_VS_MAIN-1); sync_dur_post<=(SYNC_DUR_VS_POST-1); sync_trig<=1;
                    end else begin
                        if ( trig_scanline_nearend ) begin
                            sync_dur_pre<=(SYNC_DUR_H_PRE-1); sync_dur_main<=(SYNC_DUR_H_MAIN-1); sync_dur_post<=(SYNC_DUR_H_POST-1); sync_trig<=1;
                        end else begin
                            sync_trig<=0;
                        end
                    end
                end
                default: begin
                    sync_trig<=0;
                end
            endcase
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// x position, visibility and position trigger management
//////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (reset || (~cv_en) ) begin 
        x_pos<=0; x_pos_cnt<=0; x_vis<=0;
    end else begin
        if ( clk_en_pixel ) begin
            if ( x_vis_trig_on ) begin
                x_vis<=1;
            end else begin
                if ( x_vis_trig_off ) begin
                    x_vis<=0;
                end
            end
            if ( x_pos_cnt_on ) begin
                x_pos_cnt<=1;
            end else begin
                if ( x_pos_cnt_off ) begin
                    x_pos_cnt<=0;
                end
            end
            if ( x_pos_clr ) begin
                x_pos<=0; 
            end else begin
                if ( x_pos_cnt ) begin
                    x_pos<=x_pos+1;
                end
            end
        end
    end
end
always @ (*) begin
    x_vis_trig_on=0; x_vis_trig_off=0; x_pos_clr=0; x_pos_cnt_on=0; x_pos_cnt_off=0;
    case (fsm_frame_state)
        FSM_FRAME_S_F0_NV: // 3
        begin
            if ( hsl_cnt_zero ) begin
                x_vis_trig_on=1;
            end else begin
                x_vis_trig_off=1;
            end
            case (fsm_sync_state)
                FSM_SYNC_S_PRE: begin
                    x_pos_cnt_off=1;
                    if ( sync_counter_zero ) begin
                        x_pos_clr=1;
                    end
                end
                FSM_SYNC_S_POST: begin
                    if ( sync_counter_zero ) begin
                        x_pos_cnt_on=1;
                    end
                end
                default: begin
                    x_pos_clr=0; x_pos_cnt_on=0; x_pos_cnt_off=0;
                end
            endcase
        end
        FSM_FRAME_S_F0_V,   // 4
        FSM_FRAME_S_F1_V:   // 9
        begin
            case (fsm_sync_state)
                FSM_SYNC_S_PRE: begin
                    x_vis_trig_off=1; x_pos_cnt_off=1;
                    if ( sync_counter_zero ) begin
                        x_pos_clr=1;
                    end
                end
                FSM_SYNC_S_POST: begin
                    if ( sync_counter_zero ) begin
                        x_vis_trig_on=1; x_pos_cnt_on=1;
                    end
                end
                default: begin
                    x_vis_trig_on=0; x_vis_trig_off=0; x_pos_clr=0; x_pos_cnt_on=0; x_pos_cnt_off=0;
                end
            endcase
        end
        FSM_FRAME_S_F1_VSYNC_PRE0: // 13
        begin
            if ( trig_scanline_nearend ) begin
                x_vis_trig_off=1; x_pos_cnt_off=1;
            end
        end
        FSM_FRAME_S_F0_VSYNC_PRE0: // 14
        begin
            case (fsm_sync_state)
                FSM_SYNC_S_PRE: begin
                    if ( sync_counter_zero ) begin
                        x_pos_clr=1;
                    end
                end
                FSM_SYNC_S_POST: begin
                    if ( sync_counter_zero ) begin
                        x_vis_trig_on=1; x_pos_cnt_on=1;
                    end
                end
                default: begin
                    x_vis_trig_on=0; x_vis_trig_off=0; x_pos_clr=0; x_pos_cnt_on=0; x_pos_cnt_off=0;
                end
            endcase
        end
        FSM_FRAME_S_F0_VSYNC_PRE1, // 5
        FSM_FRAME_S_F1_VSYNC_PRE1: //10
        begin
            x_vis_trig_off=1; x_pos_clr=1; x_pos_cnt_off=1;
        end
        default: begin
            x_vis_trig_on=0; x_vis_trig_off=0; x_pos_clr=0; x_pos_cnt_on=0; x_pos_cnt_off=0;
        end
    endcase
end

//////////////////////////////////////////////////////////////////////////////////
// y position management
//////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (reset || (~cv_en) ) begin 
        y_pos<=0;
    end else begin
        if ( clk_en_pixel ) begin
            case (fsm_frame_state)
                FSM_FRAME_S_F0_VSYNC_MAIN:
                begin
                    y_pos<=0;
                end
                FSM_FRAME_S_F1_VSYNC_MAIN:
                begin
                    y_pos<=1;
                end
                FSM_FRAME_S_F0_V,
                FSM_FRAME_S_F1_V:
                begin
                    if ( trig_scanline_clamp_m1 ) begin
                        y_pos<=y_pos+2;
                    end
                end
                default: begin
                    y_pos<=y_pos;
                end
            endcase
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Frame state machine
//////////////////////////////////////////////////////////////////////////////////
// Management of state register:
always @(posedge clk) begin
    if (reset || (~cv_en) ) begin 
        fsm_frame_state<=FSM_FRAME_S_RESET;
    end else begin
        if ( clk_en_pixel ) begin
            fsm_frame_state<=fsm_frame_state_next;
        end
    end
end
// Next-state and output logic. Combinational.
always @(*) begin
    fsm_frame_state_next=fsm_frame_state;
    hsl_cnt_load=0; hsl_cnt_load_v=0;
    case (fsm_frame_state)
        FSM_FRAME_S_WAIT: begin
            if ( trig_scanline_clamp && scanline_cnt_max ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_MAIN;
                hsl_cnt_load_v=5; hsl_cnt_load=1;
            end
        end
        // Field 0
        FSM_FRAME_S_F0_VSYNC_MAIN: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_POST0;
                hsl_cnt_load_v=4; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_VSYNC_POST0: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_POST1;
                hsl_cnt_load_v=1; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_VSYNC_POST1: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_NV;
                hsl_cnt_load_v=35; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_NV: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_V;
                hsl_cnt_load_v=574; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_V: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_VSYNC_PRE0;
                hsl_cnt_load_v=1; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_VSYNC_PRE0: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_VSYNC_PRE1;
                hsl_cnt_load_v=5; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_VSYNC_PRE1: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_VSYNC_MAIN;
                hsl_cnt_load_v=5; hsl_cnt_load=1;
            end
        end
        // Field 1
        FSM_FRAME_S_F1_VSYNC_MAIN: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_VSYNC_POST0;
                hsl_cnt_load_v=4; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_VSYNC_POST0: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_VSYNC_POST1;
                hsl_cnt_load_v=1; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_VSYNC_POST1: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_NV;
                hsl_cnt_load_v=35; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_NV: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F1_V;
                hsl_cnt_load_v=574; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F1_V: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_PRE0;
                hsl_cnt_load_v=1; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_VSYNC_PRE0: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_PRE1;
                hsl_cnt_load_v=5; hsl_cnt_load=1;
            end
        end
        FSM_FRAME_S_F0_VSYNC_PRE1: begin
            if ( hsl_cnt_zero ) begin
                fsm_frame_state_next=FSM_FRAME_S_F0_VSYNC_MAIN;
                hsl_cnt_load_v=5; hsl_cnt_load=1;
            end
        end
        default: begin
            // reset, and recovery from unexpected states
            fsm_frame_state_next=FSM_FRAME_S_WAIT;
        end
    endcase
end

//////////////////////////////////////////////////////////////////////////////////
// Sync state machine
//////////////////////////////////////////////////////////////////////////////////
// Management of state register:
always @(posedge clk) begin
    if (reset || (~cv_en) ) begin 
        fsm_sync_state<=FSM_SYNC_S_RESET;
    end else begin
        if ( clk_en_pixel ) begin
            fsm_sync_state<=fsm_sync_state_next;
        end
    end
end
// Next-state and output logic. Combinational.
always @(*) begin
    // define default next state, and default outputs
    fsm_sync_state_next=fsm_sync_state;
    sync_counter_load=0; sync_counter_value=0;
    cv_sync_pre=0; cv_sync_main=0; cv_sync_post=0;
    case (fsm_sync_state)
        FSM_SYNC_S_WAIT: begin
            if ( sync_trig ) begin
                sync_counter_load=1; sync_counter_value=sync_dur_pre;
                fsm_sync_state_next=FSM_SYNC_S_PRE;
            end
        end
        FSM_SYNC_S_PRE: begin
            cv_sync_pre=1;
            if ( sync_trig ) begin
                sync_counter_load=1; sync_counter_value=sync_dur_pre;
                fsm_sync_state_next=FSM_SYNC_S_PRE;
            end else begin
                if ( sync_counter_zero ) begin
                    sync_counter_load=1; sync_counter_value=sync_dur_main;
                    fsm_sync_state_next=FSM_SYNC_S_MAIN;
                end
            end
        end
        FSM_SYNC_S_MAIN: begin
            cv_sync_main=1;
            if ( sync_trig ) begin
                // if a sync trigger arrives during main, stay in main, but refresh duration
                sync_counter_load=1; sync_counter_value=sync_dur_main;
                fsm_sync_state_next=FSM_SYNC_S_MAIN;
            end else begin
                if ( sync_counter_zero ) begin
                    sync_counter_load=1; sync_counter_value=sync_dur_post;
                    fsm_sync_state_next=FSM_SYNC_S_POST;
                end
            end
        end
        FSM_SYNC_S_POST: begin
            cv_sync_post=1;
            if ( sync_trig ) begin
                sync_counter_load=1; sync_counter_value=sync_dur_pre;
                fsm_sync_state_next=FSM_SYNC_S_PRE;
            end else begin
                if ( sync_counter_zero ) begin
                    fsm_sync_state_next=FSM_SYNC_S_WAIT;
                end
            end
        end
        default: begin
            // reset, and recovery from unexpected states
            fsm_sync_state_next=FSM_SYNC_S_WAIT;
        end
    endcase
end

//////////////////////////////////////////////////////////////////////////////////
// Sync counter
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        sync_counter<=0;
    end
    else begin
        if ( clk_en_pixel ) begin
            if ( sync_counter_load ) begin
                sync_counter<=sync_counter_value;
            end else if ( ~sync_counter_zero ) begin
                sync_counter<=sync_counter-1;
            end
        end
    end
end
assign sync_counter_zero=(sync_counter==0);

//////////////////////////////////////////////////////////////////////////////////
// Drive test/debug outputs cv_sync_v and cv_sync_h
//////////////////////////////////////////////////////////////////////////////////
assign cv_sync_v=(fsm_frame_state==FSM_FRAME_S_F0_VSYNC_MAIN)||(fsm_frame_state==FSM_FRAME_S_F1_VSYNC_MAIN);
assign cv_sync_h=( (fsm_frame_state==FSM_FRAME_S_F0_V)||(fsm_frame_state==FSM_FRAME_S_F1_V) ) && (fsm_sync_state==FSM_SYNC_S_MAIN );

endmodule
