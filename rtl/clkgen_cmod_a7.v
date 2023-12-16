//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Artix7 MMCM-based clock generator
// Author: Karl Rinne
// Create Date: 20/06/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2001
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

// [20] Xilinx "Artix-7 FPGAs Data Sheet: DC and AC Switching Characteristics"
// [21] Xilinx "7 Series FPGAs Clock Resources User Guide"

`include "timing.v"

module clkgen_cmod_a7
(
    input wire          clk_raw_in,         // clock from input pin
    input wire          reset_async,        // reset input (async)
    output wire         clk_200MHz,
    output wire         clk_100MHz,
    output wire         clk_50MHz,
    output wire         clk_20MHz,
    output wire         clk_12MHz,
    output wire         clk_10MHz,
    output wire         clk_5MHz,
    output wire         clk_locked
);

    wire                clk_feedback;
    wire                clk_200MHz_weak;
    wire                clk_100MHz_weak;
    wire                clk_50MHz_weak;
    wire                clk_20MHz_weak;
    wire                clk_12MHz_weak;
    wire                clk_10MHz_weak;
    wire                clk_5MHz_weak;

// The MMCM template below was taken directly from Vivado->Language Templates->Verilog->Device Primitive Instantiation->Clock Components->MMCM

// Info for CmodA7-15T using XC7A15T-1CPG236C
// =======================================================
// External clock generator produces 12MHz and delivers schematic signal GCLK to FPGA pin L17 (in Bank 14)
// fclkin=12MHz, translating into Tclkin=83.333ns (attribute .CLKIN1_PERIOD in ps resolution)
//  => .CLKIN1_PERIOD(83.333)
// fvco=600MHz (in order to achieve 100MHz target frequency, and derived frequencies). Can't go higher as M is restricted to 2<=M<=64
//  => M=600/12=50 => .CLKFBOUT_MULT_F(50.0)
// fclkout0=200MHz => CLKOUT0_DIVIDE_F(3.0)
// fclkout1=100MHz => CLKOUT1_DIVIDE_F(6)
// fclkout2= 50MHz => CLKOUT2_DIVIDE_F(3)
// fclkout3= 20MHz => CLKOUT3_DIVIDE_F(3)
// fclkout4= 12MHz => CLKOUT4_DIVIDE_F(3)
// fclkout5= 10MHz => CLKOUT5_DIVIDE_F(3)
// fclkout6=  5MHz => CLKOUT6_DIVIDE_F(3)

    // Instantiate an input clock buffer (IBUFG, see [21] p.89. Template from language templates
    IBUF #(
        .IBUF_LOW_PWR("TRUE"),  // Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
    ) IBUF_clk_raw_in (
        .O(clk_raw_in_buffered),     // Buffer output
        .I(clk_raw_in)          // Buffer input (connect directly to top-level port)
    );

    // MMCME2_BASE: Base Mixed Mode Clock Manager
    //              Artix-7
    // Xilinx HDL Language Template, version 2019.2
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),    // Jitter programming (OPTIMIZED, HIGH, LOW)
        .CLKFBOUT_MULT_F(50.0),     // Multiply value for all CLKOUT (2.000-64.000).
        .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB (-360.000-360.000).
        .CLKIN1_PERIOD(83.333),     // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
        // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
        .CLKOUT1_DIVIDE(6),         // 100MHz
        .CLKOUT2_DIVIDE(12),        //  50MHz
        .CLKOUT3_DIVIDE(30),        //  20MHz
        .CLKOUT4_DIVIDE(50),        //  12MHz
        .CLKOUT5_DIVIDE(60),        //  10MHz
        .CLKOUT6_DIVIDE(120),       //   5MHz
        .CLKOUT0_DIVIDE_F(3.0),     // 200MHz Divide amount for CLKOUT0 (1.000-128.000).
        // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT6_DUTY_CYCLE(0.5),
        // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_PHASE(0.0),
        .CLKOUT2_PHASE(0.0),
        .CLKOUT3_PHASE(0.0),
        .CLKOUT4_PHASE(0.0),
        .CLKOUT5_PHASE(0.0),
        .CLKOUT6_PHASE(0.0),
        .CLKOUT4_CASCADE("FALSE"),  // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
        .DIVCLK_DIVIDE(1),          // Master division value (1-106)
        .REF_JITTER1(0.01),         // Reference input jitter in UI (0.000-0.999).
        .STARTUP_WAIT("FALSE")      // Delays DONE until MMCM is locked (FALSE, TRUE)
    )
    MMCME2_BASE_inst (
        // Clock Outputs: 1-bit (each) output: User configurable clock outputs
        .CLKOUT0(clk_200MHz_weak),  // 1-bit output: CLKOUT0
        .CLKOUT0B(),                // 1-bit output: Inverted CLKOUT0
        .CLKOUT1(clk_100MHz_weak),  // 1-bit output: CLKOUT1
        .CLKOUT1B(),                // 1-bit output: Inverted CLKOUT1
        .CLKOUT2(clk_50MHz_weak),   // 1-bit output: CLKOUT2
        .CLKOUT2B(),                // 1-bit output: Inverted CLKOUT2
        .CLKOUT3(clk_20MHz_weak),   // 1-bit output: CLKOUT3
        .CLKOUT3B(),                // 1-bit output: Inverted CLKOUT3
        .CLKOUT4(clk_12MHz_weak),   // 1-bit output: CLKOUT4
        .CLKOUT5(clk_10MHz_weak),   // 1-bit output: CLKOUT5
        .CLKOUT6(clk_5MHz_weak),    // 1-bit output: CLKOUT6
        // Feedback Clocks: 1-bit (each) output: Clock feedback ports
        .CLKFBOUT(clk_feedback),    // 1-bit output: Feedback clock
        .CLKFBOUTB(),               // 1-bit output: Inverted CLKFBOUT
        // Status Ports: 1-bit (each) output: MMCM status ports
        .LOCKED(clk_locked),        // 1-bit output: LOCK
        // Clock Inputs: 1-bit (each) input: Clock input
        .CLKIN1(clk_raw_in_buffered),   // 1-bit input: Clock
        // Control Ports: 1-bit (each) input: MMCM control ports
        .PWRDWN(0),                 // 1-bit input: Power-down
        .RST(reset_async),          // 1-bit input: Reset
        // Feedback Clocks: 1-bit (each) input: Clock feedback ports
        .CLKFBIN(clk_feedback)      // 1-bit input: Feedback clock
    );

    // global clock buffers with clock enable (BUFGCE), from language template
    BUFGCE #( .SIM_DEVICE("7SERIES") ) BUFGCE_200MHz (
        .O(clk_200MHz),
        .CE(clk_locked),
        .I(clk_200MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_100MHz (
        .O(clk_100MHz),
        .CE(clk_locked),
        .I(clk_100MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_50MHz (
        .O(clk_50MHz),
        .CE(clk_locked),
        .I(clk_50MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_20MHz (
        .O(clk_20MHz),
        .CE(clk_locked),
        .I(clk_20MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_12MHz (
        .O(clk_12MHz),
        .CE(clk_locked),
        .I(clk_12MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_10MHz (
        .O(clk_10MHz),
        .CE(clk_locked),
        .I(clk_10MHz_weak)
    );
    BUFGCE #( .SIM_DEVICE("7SERIES") )  BUFGCE_5MHz (
        .O(clk_5MHz),
        .CE(clk_locked),
        .I(clk_5MHz_weak)
    );

endmodule
