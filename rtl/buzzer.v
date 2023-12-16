//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: Simple buzzer
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

`include "timing.v"

module buzzer
#(
    parameter           BUZZER_RLD=24_999,      // Clock cycles per single pulse, giving Tbuzzer_period/2, defaulting to Tbuzzer=500us
    parameter           BUZZER_RLD_TURBOSIM=24,
    parameter           BUZZER_DUR=399,         // Duration of buzz, multiple of Tbuzzer_period/2, defaulting to 100ms
    parameter           BUZZER_DUR_TURBOSIM=4
)
(
    input wire          clk,                // clock input (rising edge)
    input wire          reset,              // reset input (synchronous)
    input wire          turbosim,           // speeds up simulation
    input wire          en_posedge,         // en pos-edge detect, otherwise enables permanent buzz
    input wire          en,                 // Enables display if 1
    output wire         buzzer_p,           // buzzer, positive terminal
    output wire         buzzer_n            // buzzer, negative terminal
);

`include "wordlength.v"

reg [wordlength(BUZZER_RLD)-1:0]    buzzer_rld_value;
reg [wordlength(BUZZER_RLD)-1:0]    buzzer_counter_pulse;
wire                                buzzer_counter_pulse_zero;
reg [wordlength(BUZZER_DUR)-1:0]    buzzer_dur_rld_value;
reg [wordlength(BUZZER_DUR)-1:0]    buzzer_dur_counter;

reg                                 buzzer;
reg                                 buzzer_on;
reg [1:0]                           buzzer_en;
wire                                buzzer_en_posedge;
wire                                buzzer_en_dur_reload;

// ************************************************************************************************
// Buzzer. Reload muxes
// ************************************************************************************************
always @(*) begin
    if (turbosim) begin
        buzzer_rld_value=BUZZER_RLD_TURBOSIM;
        buzzer_dur_rld_value=BUZZER_DUR_TURBOSIM;
    end else begin
        buzzer_rld_value=BUZZER_RLD;
        buzzer_dur_rld_value=BUZZER_DUR;
    end
end

// ************************************************************************************************
// Buzzer. Output
// ************************************************************************************************
assign buzzer_p=(buzzer_on)?buzzer:0;
assign buzzer_n=(buzzer_on)?~buzzer:0;

// ************************************************************************************************
// Buzzer. Pulse counter, setting audible frequency of buzz
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        buzzer<=0; buzzer_counter_pulse<=0;
    end else begin
        if (buzzer_on) begin
            if (buzzer_counter_pulse_zero) begin
                buzzer<=~buzzer;
                buzzer_counter_pulse<=buzzer_rld_value;
            end else begin
                buzzer_counter_pulse<=buzzer_counter_pulse-1;
            end
        end else begin
            buzzer<=0; buzzer_counter_pulse<=buzzer_rld_value;
        end
    end
end
assign buzzer_counter_pulse_zero=(buzzer_counter_pulse==0);

// ************************************************************************************************
// Buzzer. On/off trigger and control
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        buzzer_en<=2'b00;
    end else begin
        buzzer_en<={buzzer_en[0],en};
    end
end
// detection of positive edge
assign buzzer_en_posedge=(buzzer_en==2'b01);
assign buzzer_en_dur_reload=buzzer_en_posedge | (en&(~en_posedge));

// ************************************************************************************************
// buzzer duration and buzzer_on management
// ************************************************************************************************
always @ (posedge clk) begin
    if (reset) begin
        buzzer_dur_counter<=0; buzzer_on<=0;
    end else begin
        if ( buzzer_en_dur_reload ) begin
            buzzer_dur_counter<=buzzer_dur_rld_value;
             buzzer_on<=1;
        end else begin
            if (buzzer_dur_counter) begin
                if (buzzer_counter_pulse_zero) begin
                    buzzer_dur_counter<=buzzer_dur_counter-1;
                end
            end else begin
                buzzer_on<=0;
            end
        end
    end
end

endmodule
