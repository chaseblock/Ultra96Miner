`timescale 1ns / 1ps

// Generate the message schedule for the computation
module sha2_schedule(
    input [31:0] w [15:0],
    output [31:0] w_next [15:0]
    );

    // Most of the values are just shifted down
    genvar i;
    generate
        for(i = 0; i < 15; i=i+1) begin
            assign w_next[i] = w[i+1];
        end
    endgenerate
    
    // The new final element is the only one that
    // requires actual computation.
    wire [31:0] y0 = w[1];
    wire [31:0] y1 = w[14];

    wire [31:0] y0_7  = {y0[6:0], y0[31:7]};
    wire [31:0] y0_18 = {y0[17:0], y0[31:18]};
    wire [31:0] y0_3  = {3'b0, y0[31:3]};

    wire [31:0] s0 = y0_7 ^ y0_18 ^ y0_3;

    wire [31:0] y1_17 = {y1[16:0], y1[31:17]};
    wire [31:0] y1_19 = {y1[18:0], y1[31:19]};
    wire [31:0] y1_10 = {10'b0, y1[31:10]};

    wire [31:0] s1 = y1_17 ^ y1_19 ^ y1_10;
    
    assign w_next[15] = w[0] + s0 + w[9] + s1;

endmodule