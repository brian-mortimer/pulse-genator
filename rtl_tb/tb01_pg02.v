//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Design: EE6621 pg02
// Author:Brian Mortimer
// Create Date: 10/12/2020
// Design Name: generic
// Revision: 1.0
//////////////////////////////////////////////////////////////////////////////////

module tb01_pg02;

    reg         clk;
    reg         reset;
    reg [1:0]   buttons;            // {L,R}
    reg         muxpb;

    // 7-segment display
    wire [7:0]  d7_cathodes_n;
    wire [7:0]  d7_anodes;
    wire [15:0] bcd;
    wire [3:0]  fsm_state;
    wire        blink;
    wire        buzzer_p;

	// tb general purpose integer variables
	integer		i0;
    integer     error_counter;
    
    integer i;
    reg [10:0] prbs_sum;
    reg [10:0] prbs_mean;

    // definition of buttons
    localparam              B_RIGHT_ARROW=8'b0000_0100;
    localparam              B_LEFT_ARROW=8'b0000_1000;
    localparam              B_UP_ARROW=8'b0010_0000;
    localparam              B_DOWN_ARROW=8'b0001_0000;
    localparam              B_OK=8'b0100_0000;
    localparam              B_ESC=8'b1000_0000;
    localparam              B_RIGHT_BTN=8'b1000_0010;
    localparam              B_LEFT_BTN=8'b1000_0001;
    
    localparam              SHORT_WAIT=250000;


    // Generate 100MHz clock signal
    initial begin
        clk = 0;                    
        #5;                         
        forever #5 clk=~clk;        
    end

//    // Generate reset signal
    initial begin
        reset=1;                    // Assert reset at time 0, wait for 6 clk edges, then de-assert reset
        for(i0=0;i0<6;i0=i0+1) begin
            @(posedge clk);
        end
        #2; reset=0;
    end

    // Take game FSM through some key operations, and check response
    initial begin
        error_counter=0;
        
        $strobe("========================================================");
        $strobe("Sim Info: Start Sim.");
        $strobe("========================================================");
        pg02.test_buttons = 8'b0;
        
        
        #20
        $strobe("Sim Info: Test 1. Run one complete display cycle, check for string 'UL    '");

        wait ( d7_anodes==6'b0001_0000 )
        #10
        if ( d7_cathodes_n==8'b1100_0111 ) begin
        end else begin
            $strobe("FAIL: wrong character in display position 4, expected 'L'");
            error_counter=error_counter+1;
        end

        wait ( d7_anodes==6'b0010_0000 )
        #10
        if ( d7_cathodes_n==8'b1100_0001 ) begin
            $strobe("Sim Info: Test 1. *** PASS ***");
        end else begin
            $strobe("FAIL: wrong character in display position 5, expected 'U'");
            error_counter=error_counter+1;
        end
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 2. Test Default Tph and Tpl");
        
        wait( fsm_state==5 );
        if ( pg02.tph == {1'b1, 7'h2, 8'h0} & pg02.tpl == {1'b1 , 7'h8, 8'h0}) begin
            $strobe("Sim Info: Test 2. *** PASS ***");
        end else begin
            $strobe("FAIL: wrong tph or tpl values.");
            error_counter=error_counter+1;
        end
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 3. Test enter Set Pulse Mode State");
        #SHORT_WAIT;
        pg02.test_buttons = B_RIGHT_ARROW;
        wait( fsm_state==6 );
        pg02.test_buttons = 8'b0;
        $strobe("Sim Info: Test 3. *** PASS ***");
        #SHORT_WAIT;
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 4. Change Selected Digit");
        
        pg02.test_buttons = B_RIGHT_ARROW;
        wait( pg02.tp_selected ==1);
        pg02.test_buttons = 8'b0;
        #SHORT_WAIT;
        if ( pg02.tp_selected != 1) begin
            $strobe("FAIL: Failed to changed selected digit");
            error_counter=error_counter+1;
        end
        $strobe("Sim Info: Test 4. *** PASS ***");
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 5. Increase Tph and save");
        pg02.test_buttons = B_UP_ARROW;
        #SHORT_WAIT;
        pg02.test_buttons = 8'b0;
        #SHORT_WAIT;
        pg02.test_buttons = B_OK;
        #SHORT_WAIT;
        pg02.test_buttons = 8'b0;
        #SHORT_WAIT;
        if ( pg02.tph != {1'b1, 7'h2, 8'h1}) begin
            $strobe("FAIL: Failed to increment and save Tph");
            error_counter=error_counter+1;
        end
        $strobe("Sim Info: Test 5. *** PASS ***");
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 6. Test Signal Out and Signal Cycle");
        wait( signal_out == 0);
        wait( signal_out == 1);
        if ( signal_cycle != 1) begin
            $strobe("FAIL: Failed to trigger signal_cycle");
            error_counter=error_counter+1;
        end
        #2101;
        if ( signal_out == 1) begin
            $strobe("FAIL: Signal out timing is incorrect");
            error_counter=error_counter+1;
        end else begin 
            $strobe("Sim Info: Test 6. *** PASS ***");
        end
        $strobe("========================================================");
        
        
        $strobe("Sim Info: Test 7. Test Enter PRBS Mode");
       
        pg02.test_buttons = B_OK;
        wait (fsm_state == 7);
        pg02.test_buttons = 8'b0;
        #SHORT_WAIT;
        $strobe("Sim Info: Test 7. *** PASS ***");
        $strobe("========================================================");

        
        $strobe("Sim Info: Test 8. Test Signal Out and Signal Cycle");
        wait( signal_cycle == 0);
        wait( signal_cycle == 1);
        #256001;
        if ( signal_out == 1) begin
            $strobe("FAIL: PRBS signal cycle timing is incorrect");
            error_counter=error_counter+1;
        end else begin 
            $strobe("Sim Info: Test 8. *** PASS ***");
        end
        $strobe("========================================================");
        
        $strobe("Sim Info: Test 8. Test PRBS Signal Out and Signal Cycle");
        wait( signal_cycle == 0);
        wait( signal_cycle == 1);
        prbs_sum = 0;
        for (i = 0; i < 256; i = i+1) begin
            if ( signal_out ==1) prbs_sum = prbs_sum +1;
            #1000;
        end
        $strobe("PRBS out sum = %d ",prbs_sum);
        if (prbs_sum == 128) begin
            $strobe("PRBS is 50% 1's and 50% 0's as expected");
        end else begin
            $strobe("FAIL: PRBS signal out is not random");
            error_counter=error_counter+1;
        end
        
        if ( signal_out == 1) begin
            $strobe("FAIL: PRBS signal cycle timing is incorrect");
            error_counter=error_counter+1;
        end else begin 
            $strobe("Sim Info: Test 8. *** PASS ***");
        end
        
        $strobe("========================================================");
        $strobe("Sim Info: Simulation finished normally with %0d error(s).",error_counter);
        $strobe("========================================================");

        #10 $finish;
    end
    
    initial begin
        #1_000_000_000      // define hard-stop time for simulation
        $strobe("Sim Info: Simulation hard-stopped at time %0t",$time);
        $finish;
    end

    pg02 pg02
    (
        .clk(clk), 
        .reset(reset),
        .turbosim(1'b1),
        .buttons(buttons),
        .muxpb(muxpb),
        .d7_cathodes_n(d7_cathodes_n),
        .d7_anodes(d7_anodes),
        .blink(blink),
        .buzzer_p(buzzer_p),
        .buzzer_n(buzzer_n),
        .fsm_state(fsm_state),
        .signal_out(signal_out),
        .signal_cycle(signal_cycle)
    );


endmodule
