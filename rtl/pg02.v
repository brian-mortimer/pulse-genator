//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [2] Karle Rinne, rt2.v

`include "timing.v"

module pg02
(
    input wire                  clk,
    input wire                  reset,
    input wire					turbosim,
    input wire [1:0]            buttons,        // {L, R}
    input wire                  muxpb,
    output wire [7:0]           d7_cathodes_n,  // {DP,CG,CF,CE,CD,CC,CB,CA}
    output wire [7:0]           d7_anodes,
    output wire                 blink,
    output wire                 buzzer_p,
    output wire                 buzzer_n,
    output wire                 cv_chrom,
    output wire [2:0]           cv_lum,
    output wire                 cv_sync,
    output wire                 cv_sync_h,
    output wire                 cv_sync_v,
    output wire [3:0]           fsm_state,
    output wire                 signal_out,
    output wire                 signal_cycle
);

    localparam  d7_space=8'b00000000;    // display character ' '
    localparam  d7_C=8'b0011_1001;       // display character 'C'
    localparam  d7_E=8'b0111_1001;       // display character 'E'
    localparam  d7_L=8'b0011_1000;       // display character 'L'
    localparam  d7_U=8'b0011_1110;       // display character 'U'
    localparam  d7_p=8'b0111_0011;       // display character 'p'
    localparam  d7_g=8'b0110_1111;       // display character 'g'
    localparam  d7_r=8'b0101_0000;       // display character 'r'
    localparam  d7_b=8'b0111_1100;       // display character 'b'
    
    // Pulse Mode Values
    reg [15:0]                  tph;
    reg [15:0]                  tpl;
    reg [15:0]                  next_tph;
    reg [15:0]                  next_tpl;
    wire [15:0]                 tph_temp;
    wire [15:0]                 tpl_temp;
    wire                        tp_edit_enable;
    wire                        tp_adj;
    wire                        tp_temp_sync;
    wire                        tp_save;
    wire [2:0]                  tp_selected;
    reg [7:0]                   d7_tp_selected;
    
    wire                        prbs_en;
    wire                        prbs_signal_out;
    wire                        prbs_signal_cycle;
    wire                        pm_signal_out;
    wire                        pm_signal_cycle;

    wire                        reset_s;
    wire                        clk_ev_1ms;
    wire                        clk_ev_100us;

    wire                        button_l;       
    wire                        button_r;       
    wire [7:0]                  mbuttons;
    reg [7:0]                   test_buttons;
    wire [7:0]                  buttons_all;
    
    wire                        beep;
    
    wire [79:0]                 d7_content_selected;
    wire [79:0]                 d7_content0;
    wire [79:0]                 d7_content1;
    wire [79:0]                 d7_content2;
    wire [79:0]                 d7_content3;
    wire [79:0]                 d7_content4;
    wire [79:0]                 d7_content5;
    wire [79:0]                 d7_content6;
    wire [79:0]                 d7_content7;
    
    wire [3:0]                  d7_content_sel;
    

    // Assign display contents (blink, mode, data)
    // "UL    "
    assign d7_content0={8'b0000_0000,8'b0000_0000, 16'h0, d7_U, d7_L, d7_space, d7_space, d7_space, d7_space};
    // "UL ECE"
    assign d7_content1={8'b0000_0000,8'b0000_0000, 16'h0, d7_U, d7_L, d7_space, d7_E,d7_C,d7_E};
    // "EE6621"
    assign d7_content2={8'b0000_0000,8'b0000_1111, 16'h0, d7_E,d7_E, 8'h6,8'h6,8'h2,8'h1};
    // "258763"
    assign d7_content3={8'b0000_0000,8'b0011_1111, 16'h0, 8'h2, 8'h5, 8'h8, 8'h7, 8'h6, 8'h3};
    // "   pg02"
    assign d7_content4={8'b0000_1111,8'b0000_0011, 16'h0, d7_space, d7_space, d7_p,d7_g, 8'h0, 8'h2};
    
    // "X.Y  Z.W" Pulse Mode
    assign d7_content5={8'b0000_0000,8'b1111_0011, 16'h0, tph , d7_space, d7_space, tpl};
    // Set Pulse Mode
    assign d7_content6={d7_tp_selected,8'b1111_0011, 16'h0, tph_temp, d7_space, d7_space, tpl_temp};
    // "prb 1.0" PRBS Mode
    assign d7_content7={8'b0000_0000,8'b0000_0011, 16'h0, d7_p , d7_r , d7_b , d7_space, {1'b1 ,7'h1} , 8'h0 };
    
    // Assing signal out depending on if prbs mode is enabled.
    assign signal_out = prbs_en ? prbs_signal_out : pm_signal_out; 
    assign signal_cycle = prbs_en ? prbs_signal_cycle : pm_signal_cycle; 
    
    always @ (posedge clk) begin
        tph<=next_tph;
        tpl<=next_tpl;
    end
    
    always @ (*) begin
        // save values
        if (tp_save==1'b1) next_tph<=tph_temp; next_tpl<=tpl_temp;
        
        // convert tp_selected to 8 bits
        case(tp_selected)
            0: d7_tp_selected=8'b0010_0000;
            1: d7_tp_selected=8'b0001_0000;
            2: d7_tp_selected=8'b0000_0010;
            3: d7_tp_selected=8'b0000_0001;
        endcase
    end
    
    
    // Synchronise the incoming raw reset signal
    synchroniser_3s synchroniser_3s_reset
    (
        .clk(clk),
        .reset(1'b0),
        .en(1'b1),
        .in(reset),
        .out(reset_s)
    );

    // Instantiate a down counter to provide 1ms time base
    counter_down_rld #( .COUNT_MAX(99_999), .COUNT_MAX_TURBOSIM(99) ) counter_1ms
    (
        .clk(clk),
        .reset(reset_s),
        .turbosim(turbosim),
        .rld(1'b0),
        .underflow(clk_ev_1ms)
    );

    // Instantiate a down counter to provide 100us time base (for sampling of button, debounce)
    counter_down_rld #( .COUNT_MAX(9_999), .COUNT_MAX_TURBOSIM(9) ) counter_100us
    (
        .clk(clk),
        .reset(reset_s),
        .turbosim(turbosim),
        .rld(1'b0),
        .underflow(clk_ev_100us)
    );

    // Instantiate a display mux
    display_7s_mux display_7s_mux
    (
        .dis_content0(d7_content0),
        .dis_content1(d7_content1),
        .dis_content2(d7_content2),
        .dis_content3(d7_content3),
        .dis_content4(d7_content4),
        .dis_content5(d7_content5),
        .dis_content6(d7_content6),
        .dis_content7(d7_content7),
        .dis_data(d7_content_selected),
        .sel(d7_content_sel)
    );

    // Instantiate a 7-segment display driver
    display_7s #( .PRESCALER_RLD(99_999), .BLINK_RLD(499) ) display_7s
    (
        .clk(clk),
        .reset(reset_s),
        .turbosim(turbosim),
        .en(1'b1),
        .dis_data(d7_content_selected[63:0]),
        .dis_mode(d7_content_selected[71:64]),
        .dis_blink(d7_content_selected[79:72]),
        .negate_a(1'b0),
        .cathodes_n(d7_cathodes_n),
        .anodes(d7_anodes),
        .blink(blink)
    );

    //Instantiate debounce for buttons[1] (left)
    debounce debounce_l
    (
        .clk(clk),
        .reset(reset_s),
        .en(clk_ev_100us),
        .signal_in(buttons[1]),
        .signal_debounced(button_l)
    );

    //Instantiate debounce for buttons[0] (right)
    debounce debounce_r
    (
        .clk(clk),
        .reset(reset_s),
        .en(clk_ev_100us),
        .signal_in(buttons[0]),
        .signal_debounced(button_r)
    );
    
    //Instantiate multiplexing for push buttons.
    mbutton #(.MUX_NOB(8)) mbutton
    (
        .clk(clk),
        .reset(reset_s),
        .muxin(d7_anodes),
        .pbin(muxpb),
        .buttons(mbuttons)
    );
    // Assign all buttons to a single array.
    assign buttons_all={mbuttons[5:0], button_l, button_r};
    //assign buttons_all=test_buttons;
    
    // Instantiate a buzzer (1.6kHz, 0.2s)
    buzzer #(.BUZZER_RLD(31_249), .BUZZER_DUR(300) ) buzzer
    (
        .clk(clk),
        .reset(reset_s),
        .turbosim(turbosim),
        .en_posedge(1'b1),
        .en(beep),
        .buzzer_p(buzzer_p),
        .buzzer_n(buzzer_n)
    );
    
    // Instantiate FSM
    fsm_app fsm_app
    (
        .clk(clk),
        .reset(reset_s),
        .timebase(clk_ev_1ms),
        .buttons(buttons_all),
        .dis_sel(d7_content_sel),
        .tp_selected(tp_selected),
        .tp_adj(tp_adj),
        .tp_edit_enable(tp_edit_enable),
        .tp_temp_sync(tp_temp_sync),
        .tp_save(tp_save),
        .prbs_en(prbs_en),
        .beep(beep),
        .fsm_state(fsm_state)
    );
    
    //Instantiate Time Pulse Controller
    time_pulse_control time_pulse_control
    (
        .clk(clk),
        .reset(reset_s),
        .in_temp_tph(tph_temp),
        .in_temp_tpl(tpl_temp),
        .in_tph(tph),
        .in_tpl(tpl),
        .tp_edit_enable(tp_edit_enable),
        .tp_selected(tp_selected),
        .tp_adj(tp_adj),
        .tp_temp_sync(tp_temp_sync),
        .out_tph(tph_temp),
        .out_tpl(tpl_temp)
    );
    
    //Instantiate Signal Generation
    signal_generator pm_signal_gen
    (
        .clk(clk),
        .reset(reset_s),
        .tph(tph),
        .tpl(tpl),
        .signal_out(pm_signal_out),
        .signal_cycle(pm_signal_cycle)
    );
    
    //Instantiate PRBS generation.
    lfsr_8bit prbs_gen
    (
        .clk(clk),
        .reset(reset),
        .signal_out(prbs_signal_out),
        .signal_cycle(prbs_signal_cycle)
    );
    
    // Instantiate composite video
    cv_core #( .CLKS_PER_PIXEL(5) ) cv_core
    (
        .clk(clk),
        .reset(reset),
        .cv_ctrl(cv_ctrl),
        .tph(tph),
        .tpl(tpl),
        .prbs_en(prbs_en),
        .cv_lum(cv_lum),
        .cv_chrom(cv_chrom),
        .cv_sync(cv_sync),
        .cv_sync_h(cv_sync_h),
        .cv_sync_v(cv_sync_v)
    );
    assign cv_ctrl={buttons_all[7:4],4'b0011};

endmodule
