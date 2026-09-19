`default_nettype none
module zu3top (
    input wire logic CLK_100_P,
    input wire logic CLK_100_N,
    input wire logic [3:0] BUTTONS,
    input wire logic [7:0] SWITCHES,
    output logic [7:0] LEDS
);
    logic CLK_100;
    IBUFDS ibufds_clk (
        .I(CLK_100_P),
        .IB(CLK_100_N),
        .O(CLK_100)
    );

    logic [7:0] adder_leds;
    logic [7:0] counter_leds;
    
    logic [14:0] adder_out;
    structural_adder user_adder (
        .a({12'b0,BUTTONS[1:0]}),
        .b({12'b0,BUTTONS[3:2]}),
        .sum(adder_out)
    );
    assign adder_leds[3:0] = adder_out[3:0]; // truncate upper bits
    
    // Self test of the structural adder
    logic [13:0] adder_operand1, adder_operand2;
    logic [14:0] structural_out, behavioral_out;
    logic test_fail;
    assign adder_leds[4] = ~test_fail;
    assign adder_leds[5] = ~test_fail;
    assign adder_leds[7:6] = 0;
    
    structural_adder structural_test_adder (
        .a(adder_operand1),
        .b(adder_operand2),
        .sum(structural_out)
    );
    
    behavioral_adder behavioral_test_adder (
        .a(adder_operand1),
        .b(adder_operand2),
        .sum(behavioral_out)
    );
    
    adder_tester tester (
        .adder_operand1(adder_operand1),
        .adder_operand2(adder_operand2),
        .structural_sum(structural_out),
        .behavioral_sum(behavioral_out),
        .clk(CLK_100),
        .test_fail(test_fail)
    );
    
    assign counter_leds[7:4] = 0;
    
    counter ctr (
        .clk(CLK_100),
        .ce(SWITCHES[0] & SWITCHES[1]),
        .LEDS(counter_leds[3:0])
    );

    assign LEDS = SWITCHES[1] ? counter_leds : adder_leds;
endmodule
