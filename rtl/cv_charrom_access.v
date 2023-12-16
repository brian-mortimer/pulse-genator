//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 FPGA Project (targeting Digilent Cmod A7-x5T)
// Author: Karl Rinne
// Design Name: Composite Video (cv). Managed shared access by up to four cv_text modules to a single character rom
// Revision: 1.0 26/10/2021
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] IEEE Standard Verilog Hardware Description Language, IEEE Std 1364-2005
// [2] Verilog Quickstart, 3rd edition, James M. Lee, ISBN 0-7923-7672-2
// [3] S. Palnitkar, "Verilog HDL: A Guide to Digital Design and Synthesis", 2nd Edition

// [10] Digilent "Nexys4 DDR FPGA Board Reference Manual", 11/04/2016, Rev C
// [11] Digilent "Nexys4 DDR Schematic", 06/10/2014, Rev C.1

// [20] http://www.batsocks.co.uk/readme/video_timing.htm

`include "timing.v"

module cv_charrom_access
#(
    parameter MAX_PORTS=4
)
(
    input wire                  clk,                // clock input (rising edge)
    input wire                  reset,              // reset input (synchronous)
    output reg [10:0]           crom_addr,          // character rom, addr
    input wire [7:0]            crom_din,           // character rom, data in
    input wire [MAX_PORTS*11-1:0]   all_addr,       // combined input address buses
    input wire [MAX_PORTS-1:0]      all_rq,         // combined read requests
    output reg [MAX_PORTS*8-1:0]    all_data        // combined data
);

// fsm_text
localparam              FSM_ACCESS_WAIT4RQ=0;
localparam              FSM_ACCESS_SERVE_RQ0=1;
localparam              FSM_ACCESS_SERVE_RQ1=2;
localparam              FSM_ACCESS_SERVE_RQ2=3;
localparam              FSM_ACCESS_RESET=7;         // make this state with largest number (determines width of state register)

reg [$clog2(FSM_ACCESS_RESET)-1:0] fsm_access_state_next, fsm_access_state;

reg [MAX_PORTS-1:0]     rq_s0, rq_s1;               // sampled request inputs
reg [MAX_PORTS-1:0]     rq_pending;                 // pending charrom read requests
reg [MAX_PORTS-1:0]     rq_pending_clr;             // pending charrom read requests, clearance
reg [MAX_PORTS-1:0]     rq_wip;                     // pending charrom read requests, request work in progress
reg [MAX_PORTS-1:0]     rq_wip_load_v;
reg rq_wip_load;

reg [10:0]              crom_addr_load_v;
reg                     crom_addr_load;

reg [MAX_PORTS*8-1:0]   all_data_load_v;
reg                     all_data_load;

reg [7:0]               crom_din_buffer;
reg                     crom_din_buffer_load;

//////////////////////////////////////////////////////////////////////////////////
// sample request inputs
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        rq_s0<=0; rq_s1<=0;
    end else begin
        rq_s1<=rq_s0; rq_s0<=all_rq;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage pending read requests
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        rq_pending<=0;
    end else begin
        rq_pending<=(rq_pending | ((~rq_s1) & rq_s0) ) & ~rq_pending_clr;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage work-in-progress requests
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        rq_wip<=0;
    end else begin
        if (rq_wip_load) begin
            rq_wip<=rq_wip_load_v;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage crom address
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        crom_addr<=0;
    end else begin
        if (crom_addr_load) begin
            crom_addr<=crom_addr_load_v;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage crom data buffer
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        crom_din_buffer<=0;
    end else begin
        if (crom_din_buffer_load) begin
            crom_din_buffer<=crom_din;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// manage output data bus
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk) begin
    if ( reset ) begin
        all_data<=0;
    end else begin
        if (all_data_load) begin
            all_data<=all_data_load_v;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// FSM access
//////////////////////////////////////////////////////////////////////////////////
// Management of state register:
always @(posedge clk) begin
    if (reset ) begin 
        fsm_access_state<=FSM_ACCESS_RESET;
    end else begin
        fsm_access_state<=fsm_access_state_next;
    end
end
// Next-state and output logic. Combinational.
always @(*) begin
    fsm_access_state_next=fsm_access_state;
    rq_pending_clr=0; rq_wip_load_v=0; rq_wip_load=0;
    crom_addr_load_v=0; crom_addr_load=0;
    crom_din_buffer_load=0; all_data_load_v=0; all_data_load=0;
    case ( fsm_access_state )
        FSM_ACCESS_WAIT4RQ: begin
            casex ( rq_pending )
                4'b1xxx: begin
                    rq_wip_load_v=4'b1000; rq_wip_load=1;
                    crom_addr_load_v=all_addr[4*11-1-:11]; crom_addr_load=1;
                end
                4'b01xx: begin
                    rq_wip_load_v=4'b0100; rq_wip_load=1;
                    crom_addr_load_v=all_addr[3*11-1-:11]; crom_addr_load=1;
                end
                4'b001x: begin
                    rq_wip_load_v=4'b0010; rq_wip_load=1;
                    crom_addr_load_v=all_addr[2*11-1-:11]; crom_addr_load=1;
                end
                4'b0001: begin
                    rq_wip_load_v=4'b0001; rq_wip_load=1;
                    crom_addr_load_v=all_addr[1*11-1-:11]; crom_addr_load=1;
                end
                default: begin
                end
            endcase
            if ( rq_pending ) begin
                fsm_access_state_next=FSM_ACCESS_SERVE_RQ0;
            end else begin
                fsm_access_state_next=FSM_ACCESS_WAIT4RQ;
            end
        end
        FSM_ACCESS_SERVE_RQ0: begin
            rq_pending_clr=rq_wip;
            fsm_access_state_next=FSM_ACCESS_SERVE_RQ1;
        end
        FSM_ACCESS_SERVE_RQ1: begin
            crom_din_buffer_load=1;         // read crom data into buffer
            fsm_access_state_next=FSM_ACCESS_SERVE_RQ2;
        end
        FSM_ACCESS_SERVE_RQ2: begin
            case ( rq_wip )
                4'b1000: begin
                    all_data_load_v={crom_din_buffer,all_data[23:0]};
                end
                4'b0100: begin
                    all_data_load_v={all_data[31:24],crom_din_buffer,all_data[15:0]};
                end
                4'b0010: begin
                    all_data_load_v={all_data[31:16],crom_din_buffer,all_data[7:0]};
                end
                default: begin
                    all_data_load_v={all_data[31:8],crom_din_buffer};
                end
            endcase
            all_data_load=1;
            fsm_access_state_next=FSM_ACCESS_WAIT4RQ;
        end
        default: begin
            // reset, and recovery from unexpected states
            fsm_access_state_next=FSM_ACCESS_WAIT4RQ;
        end
    endcase
end

endmodule
