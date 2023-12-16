//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2001
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] Karle Rinne, fpga_wrapper_rt2

`include "timing.v"

module fpga_wrapper_pg02
(
    input wire                  clk_raw_in,
    input wire [1:0]            btn,
    output wire [1:0]           led,
    output wire                 led0_b,
    output wire                 led0_g,
    output wire                 led0_r,
    output wire                 pio27,  // wired to cv_sync_v
    output wire                 pio26,  // wired to cv_sync_h
    output wire                 pio23,  // wired to buzzer_p
    input  wire                 pio22,  // reserved for ee6621_ui01 pb
    output wire                 pio21,  // wired to cv_chrom
    output wire                 pio20,  // wired to cv_sync
    output wire                 pio19,  // wired to composite video
    output wire                 pio18,  // wired to composite video
    output wire                 pio17,  // wired to composite video
    output wire                 pio14,  // wired to anode base an5
    output wire                 pio13,  // wired to anode base an4
    output wire                 pio12,  // wired to anode base an3
    output wire                 pio11,  // wired to anode base an2
    output wire                 pio10,  // wired to anode base an1
    output wire                 pio9,   // wired to anode base an0
    output wire                 pio8,   // wired to cathode dp
    output wire                 pio7,   // wired to cathode g
    output wire                 pio6,   // wired to cathode f
    output wire                 pio5,   // wired to cathode e
    output wire                 pio4,   // wired to cathode d
    output wire                 pio3,   // wired to cathode c
    output wire                 pio2,   // wired to cathode b
    output wire                 pio1,   // wired to cathode a
    output wire                 ja0,    // wired to signal out
    output wire                 ja1     // wired to signal cycle
);

    // internal clock signals
    wire    clk_100MHz;
    wire    clk_locked;

    // internal signals, not brought out
    wire    an7, an6;
    
    reg reset;
    integer i0;
    
    wire cv_sync;

    // Turn off RGB LED (cathodes are driven by i/o)
    assign  led0_b=1;
    assign  led0_g=1;
    assign  led0_r=1;

    // Turn off unused green LEDs (anodes are driven by i/o)
    assign  led[1]=0;
    

    // Instantiate clock generator
    clkgen_cmod_a7 clkgen_cmod_a7
    (
        .clk_raw_in(clk_raw_in),
        .reset_async(1'b0),
        .clk_200MHz(),
        .clk_100MHz(clk_100MHz),
        .clk_50MHz(),
        .clk_20MHz(),
        .clk_12MHz(),
        .clk_10MHz(),
        .clk_5MHz(),
        .clk_locked(clk_locked)
    );

    // Instantiate 
    pg02 pg02
    (
        .clk(clk_100MHz),
        .reset(btn[0]),
        .turbosim(1'b0),
        .buttons({btn}),
        .muxpb(pio22),
        .d7_cathodes_n({pio8,pio7,pio6,pio5,pio4,pio3,pio2,pio1}),
        .d7_anodes({an7, an6, pio14,pio13,pio12,pio11,pio10,pio9}),
        .blink(led[0]),
        .buzzer_p(pio23),
        .buzzer_n(),
        .cv_chrom(pio21),   //21
        .cv_lum({pio19, pio18, pio17}),     // 19- 17
        .cv_sync(pio20),    //20
        .cv_sync_h(pio26),  //26
        .cv_sync_v(pio27),  //27
        .fsm_state(),
        .signal_out(ja0),
        .signal_cycle(ja1)
    );
    
endmodule
