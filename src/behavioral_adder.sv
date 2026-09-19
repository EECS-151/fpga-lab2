module behavioral_adder (
    input wire logic [13:0] a,
    input wire logic [13:0] b,
    output logic [14:0] sum
);
    assign sum = a + b;
endmodule
