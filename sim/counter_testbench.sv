`timescale 1ns/1ns

`define SECOND 1000000000
`define MS 1000000

module counter_testbench();
    logic clock = 0;
    logic ce;
    logic [3:0] LEDS;

    counter ctr (
        .clk(clock),
        .ce(ce),
        .LEDS(LEDS)
    );

    // Notice that this code causes the `clock` signal to constantly
    // switch up and down every 5 time steps.
    always #(5) clock <= ~clock;

    initial begin
        string fsdb_file;
        if (!$value$plusargs("fsdbfile+%s", fsdb_file)) begin
            fsdb_file = "default.fsdb";
        end 
        $fsdbDumpfile(fsdb_file)

        // TODO: Change input values and step forward in time to test
        // your counter and its clock enable/disable functionality.


        `ifndef IVERILOG
            $vcdplusoff;
        `endif
        $finish();
    end
endmodule

