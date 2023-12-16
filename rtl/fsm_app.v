//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

// References
// [1] Karle Rinne, fsm_game.v

`include "timing.v"

module fsm_app
#(
    parameter           WAIT_VLONG=3999,
    parameter           WAIT_LONG=1999,
    parameter           WAIT_MEDIUM=499,
    parameter           WAIT_SHORT=199
)
(
    input wire          clk,                // clock input (rising edge)
    input wire          reset,              // reset input (synchronous)
    input wire          timebase,           // clock time base event (1ms expected)
    input wire [7:0]    buttons,            // button to operate game (starts game sequence, stops reaction timer)
    output reg [3:0]    dis_sel,            // display select driving display mux
    output reg [2:0]    tp_selected,
    output reg          tp_adj,
    output reg          tp_edit_enable,
    output reg          tp_save,
    output reg          tp_temp_sync,
    output reg          prbs_en,
    output reg          beep,
    output wire [3:0]   fsm_state
);

`include "wordlength.v"
`include "fsm_app_states.v"

reg [S_NOB-1:0]         state;
reg [S_NOB-1:0]         next_state;

// Definitions of display strings
localparam              D_UL=0;
localparam              D_ECE=1;
localparam              D_MODULE=2;
localparam              D_STUDENT_ID=3;
localparam              D_PG02=4;
localparam              D_PULSE_MODE=5;
localparam              D_SET_PULSE_MODE=6;
localparam              D_PRBS_MODE=7;

// Definitions of button binaries
localparam              B_RIGHT_ARROW=8'b0000_0100;
localparam              B_LEFT_ARROW=8'b0000_1000;
localparam              B_UP_ARROW=8'b0010_0000;
localparam              B_DOWN_ARROW=8'b0001_0000;
localparam              B_OK=8'b0100_0000;
localparam              B_ESC=8'b1000_0000;
localparam              B_RIGHT_BTN=8'b1000_0010;
localparam              B_LEFT_BTN=8'b1000_0001;


// FSM timing
reg [wordlength(WAIT_VLONG)-1:0] counter;    // counter vector
reg [wordlength(WAIT_VLONG)-1:0] counter_load_value;
reg                     counter_load;       // counter load instruction
wire                    counter_zero;       // counter zero flag

reg [12:0]              beep_counter;

reg [2:0]               next_selected_digit;
reg                     next_adj;
reg                     next_edit_enable;
reg                     next_save;
reg                     next_temp_sync;

// make FSM state accessible
assign fsm_state=state;


// general timing
always @ (posedge clk) begin
    if (reset) begin
        counter<=0;
    end
    else begin
        if (counter_load) begin
            counter<=counter_load_value;
        end else begin
            if ( (~counter_zero) & timebase) begin
                counter<=counter-1'b1;
            end
        end
    end
end
assign counter_zero=(counter==0);

// Detect button press.
always @(posedge clk) begin
    if (buttons) begin
        beep_counter = 50;
    end
    
    if (beep_counter > 0) begin
        beep=1;
        beep_counter = beep_counter-1;
    end else beep=0;
end



always @(posedge clk) begin
    if (reset==1'b1) begin 
        state<=S_RESET;
        tp_selected<=0;
        tp_save<=1;
        tp_adj<=0;
        tp_edit_enable<=0;
        tp_temp_sync<=1;
        
    end else begin
        state<=next_state;
        tp_selected<=next_selected_digit;
        tp_edit_enable<=next_edit_enable;
        tp_save<=next_save;
        tp_adj<=next_adj;
        tp_temp_sync<=next_temp_sync;
    end
end




always @(*) begin
    // define default next state, and default outputs
    next_state=state;
    dis_sel=D_UL;
    
    prbs_en=0;
    counter_load=0; counter_load_value=WAIT_LONG;
    
    next_selected_digit=tp_selected;
    next_adj=tp_adj;
    next_save=tp_save;
    next_edit_enable=tp_edit_enable;
    
    case (state)
        S_RESET: begin
            counter_load=1; counter_load_value=WAIT_MEDIUM;
            next_state=S_SHOW_UL;
        end
        S_SHOW_UL: begin
            dis_sel=D_UL;
            if ( counter_zero & (~buttons[1]) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_SHOW_ECE;
            end
        end
        S_SHOW_ECE: begin
            dis_sel=D_ECE;
            if ( counter_zero & (~buttons[1]) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_SHOW_MODULE;
            end
        end
        S_SHOW_MODULE: begin
            dis_sel=D_MODULE;
            if ( counter_zero & (~buttons[1]) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_SHOW_STUDENT_ID;
            end
        end
        S_SHOW_STUDENT_ID: begin
            dis_sel=D_STUDENT_ID;
            if ( counter_zero & (~buttons[1]) ) begin
                counter_load=1; counter_load_value=WAIT_LONG;
                next_state=S_SHOW_DESIGN;
            end
        end
        S_SHOW_DESIGN: begin
            dis_sel=D_PG02;
            if ( counter_zero & (~buttons[1]) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_PULSE_MODE;
            end
        end
        S_PULSE_MODE: begin
            dis_sel=D_PULSE_MODE;
            prbs_en=0;
            next_edit_enable=0; next_save=0;
            
            // press left or right arrow enter set pulse mode
            if ( counter_zero & (buttons==B_LEFT_ARROW | buttons==B_RIGHT_ARROW ) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                if (buttons==B_LEFT_ARROW) next_selected_digit=3;
                if (buttons==B_RIGHT_ARROW) next_selected_digit=0;
                next_temp_sync=1;
                next_state=S_SET_PULSE_MODE;
            end
            
            // press OK  enter prbs mode
            if ( counter_zero & (buttons==B_OK) ) begin                   
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_PRBS_MODE;
            end
        end
        S_SET_PULSE_MODE: begin
            dis_sel=D_SET_PULSE_MODE;
                 
            if(tp_edit_enable) next_edit_enable=0;
            if(tp_temp_sync) next_temp_sync=0;
            
            //Down Arrow decrement value 
            if ( counter_zero & (buttons==B_DOWN_ARROW) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_adj=0; next_edit_enable=1;
            end
            
            // Up Arrow increment value
            if ( counter_zero & (buttons==B_UP_ARROW) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_adj=1; next_edit_enable=1;
            end
            
            // Left Arrow prev digit
            if ( counter_zero & (buttons==B_LEFT_ARROW) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                if (tp_selected > 0) next_selected_digit=tp_selected-1;
                else begin
                    next_save=1;
                    next_state=S_PULSE_MODE;
                end
            end
            
            // Right Arrow next digit
            if ( counter_zero & (buttons==B_RIGHT_ARROW) ) begin                      
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                if (tp_selected < 3) next_selected_digit=tp_selected+1;
                else begin
                    next_save=1;
                    next_state=S_PULSE_MODE;
                end
            end
            
            // OK save values
            if ( counter_zero & (buttons==B_OK) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_save=1;
                next_state=S_PULSE_MODE;
            end
            
            // ESC dont save values
            if ( counter_zero & (buttons==B_ESC) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_save=0;
                next_state=S_PULSE_MODE;
            end
            
        end
        S_PRBS_MODE: begin
            dis_sel=D_PRBS_MODE;
            prbs_en=1;
            
            // Press any button
            if ( counter_zero & (buttons!=8'b0) ) begin
                counter_load=1; counter_load_value=WAIT_MEDIUM;
                next_state=S_PULSE_MODE;
            end
        end
        
        default: begin
            next_state=S_RESET;	    // unexpected, but best to handle this event gracefully (e.g. single event upsets SEU's)
        end
    endcase
end
endmodule
