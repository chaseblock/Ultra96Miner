`timescale 1ns / 1ps

// Hash a single block
module sha2_chunk(
    // Clock signal
    input clk,

    // On the rising edge of the start signal, the
    // computation will begin, and will continue as
    // long as start is asserted.
    input start,

    // On reset, the internal state of the chunk computation
    // will be reset
    input reset,

    // The input data for the chunk
    input [511:0] chunk,

    // The input hash values
    input [31:0] h0,
    input [31:0] h1,
    input [31:0] h2,
    input [31:0] h3,
    input [31:0] h4,
    input [31:0] h5,
    input [31:0] h6,
    input [31:0] h7,

    // The output hash values
    output [31:0] h0_out,
    output [31:0] h1_out,
    output [31:0] h2_out,
    output [31:0] h3_out,
    output [31:0] h4_out,
    output [31:0] h5_out,
    output [31:0] h6_out,
    output [31:0] h7_out,

    // Rises when the computation is complete
    output reg done
    );

    // Temporary registers
    reg [31:0] a;
    reg [31:0] b;
    reg [31:0] c;
    reg [31:0] d;
    reg [31:0] e;
    reg [31:0] f;
    reg [31:0] g;
    reg [31:0] h;

    // Set up our hash outputs
    assign h0_out = h0 + a;
    assign h1_out = h1 + b;
    assign h2_out = h2 + c;
    assign h3_out = h3 + d;
    assign h4_out = h4 + e;
    assign h5_out = h5 + f;
    assign h6_out = h6 + g;
    assign h7_out = h7 + h;

    parameter NUM_ROUNDS = 2;

    // Counter for tracking the round
    reg [5:0] round;
    wire [5:0] next_round = round + NUM_ROUNDS;
    reg running;

    reg [31:0] w [15:0];
    
    wire [31:0] w_next [NUM_ROUNDS - 1: 0][15:0];
    wire [31:0] a_next [NUM_ROUNDS - 1: 0],
                b_next [NUM_ROUNDS - 1: 0],
                c_next [NUM_ROUNDS - 1: 0],
                d_next [NUM_ROUNDS - 1: 0],
                e_next [NUM_ROUNDS - 1: 0],
                f_next [NUM_ROUNDS - 1: 0],
                g_next [NUM_ROUNDS - 1: 0],
                h_next [NUM_ROUNDS - 1: 0];
    genvar i;
    generate
        // Generate the message schedule
        for(i = 0; i < NUM_ROUNDS; i = i + 1) begin: scheduler_loop
            if(i == 0)
                sha2_schedule scheduler(w, w_next[i]);
            else
                sha2_schedule scheduler(w_next[i-1], w_next[i]);
        end
        
        // Perform the rounds of sha256
        for(i = 0; i < NUM_ROUNDS; i = i + 1) begin: rounder_loop
            if(i == 0)
                sha2_round rounder(
                    .round(round + i),
                    .w(w[i]),
                    // Input state
                    .a(a), .b(b), .c(c), .d(d),
                    .e(e), .f(f), .g(g), .h(h),
                    // Output state
                    .a_out(a_next[0]), .b_out(b_next[0]), .c_out(c_next[0]),
                    .d_out(d_next[0]), .e_out(e_next[0]), .f_out(f_next[0]),
                    .g_out(g_next[0]), .h_out(h_next[0])
                );
            else
                sha2_round rounder(
                    .round(round + i),
                    .w(w[i]),
                    // Input state
                    .a(a_next[i-1]), .b(b_next[i-1]), .c(c_next[i-1]), .d(d_next[i-1]),
                    .e(e_next[i-1]), .f(f_next[i-1]), .g(g_next[i-1]), .h(h_next[i-1]),
                    // Output state
                    .a_out(a_next[i]), .b_out(b_next[i]), .c_out(c_next[i]),
                    .d_out(d_next[i]), .e_out(e_next[i]), .f_out(f_next[i]),
                    .g_out(g_next[i]), .h_out(h_next[i])
                );
        end
    endgenerate
    
    // Do a second round in the same cycle
//    wire [31:0] a_next2, b_next2, c_next2, d_next2, e_next2, f_next2, g_next2, h_next2;
//    sha2_round rounder2(
//        .round(round | 1),
//        .w(w[1]),
//        // Input state
//        .a(a_next), .b(b_next), .c(c_next), .d(d_next),
//        .e(e_next), .f(f_next), .g(g_next), .h(h_next),
//        // Output state
//        .a_out(a_next2), .b_out(b_next2), .c_out(c_next2),
//        .d_out(d_next2), .e_out(e_next2), .f_out(f_next2),
//        .g_out(g_next2), .h_out(h_next2)
//    );
    
    always @(posedge clk) begin
        
        if(reset) begin
            // Handle reset condition

            round <= 6'b0;
            running <= 1'b0;
            done <= 0;
        end
        else if(start && !running && !done) begin
            // Latch the inputs into our local registers, 
            // and set up for the computation
            round <= 6'b0;
            running <= 1'b1;
            done <= 0;
            a <= h0;
            b <= h1;
            c <= h2;
            d <= h3;
            e <= h4;
            f <= h5;
            g <= h6;
            h <= h7;

            // Update the message schedule with its initial values
            begin
                integer i;
                for(i = 0; i < 16; i=i+1) begin
                    w[i] <= chunk[511-i*32 -: 32];
                end
            end
        end
        else if(start && running && !done) begin
            // Latch the outputs from the round computation.
            round <= next_round;
//            a <= a_next2;
//            b <= b_next2;
//            c <= c_next2;
//            d <= d_next2;
//            e <= e_next2;
//            f <= f_next2;
//            g <= g_next2;
//            h <= h_next2;

//            // Update the message schedule
//            w <= w_next2;
            
            a <= a_next[NUM_ROUNDS-1];
            b <= b_next[NUM_ROUNDS-1];
            c <= c_next[NUM_ROUNDS-1];
            d <= d_next[NUM_ROUNDS-1];
            e <= e_next[NUM_ROUNDS-1];
            f <= f_next[NUM_ROUNDS-1];
            g <= g_next[NUM_ROUNDS-1];
            h <= h_next[NUM_ROUNDS-1];

            // Update the message schedule
            w <= w_next[NUM_ROUNDS-1];
            
            // Check for ending condition
            if(next_round == 6'b0) begin
                done <= 1;
                running <= 0;
            end
        end
        else if(!start) begin
            done <= 0;      // Deassert the done signal if start has fallen
            running <= 0;   // Stop the computation 
        end
    end

endmodule
