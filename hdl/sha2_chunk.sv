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

    // Counter for tracking the round
    reg [5:0] round;
    wire [5:0] next_round = round + 1;
    reg running;

    // Our message schedule buffer
    reg [31:0] w [15:0];
    wire [31:0] w_next [15:0];
    sha2_schedule scheduler(w, w_next);

    // Logic for computing the output of this round
    wire [31:0] a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next;
    sha2_round rounder(
        .round(round),
        .w(w[0]),
        // Input state
        .a(a), .b(b), .c(c), .d(d),
        .e(e), .f(f), .g(g), .h(h),
        // Output state
        .a_out(a_next), .b_out(b_next), .c_out(c_next),
        .d_out(d_next), .e_out(e_next), .f_out(f_next),
        .g_out(g_next), .h_out(h_next)
    );
    
    integer i;
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
            for(i = 0; i < 16; i=i+1) begin
                w[i] <= chunk[511-i*32 -: 32];
            end
        end
        else if(start && running && !done) begin
            // Latch the outputs from the round computation.
            round <= next_round;
            a <= a_next;
            b <= b_next;
            c <= c_next;
            d <= d_next;
            e <= e_next;
            f <= f_next;
            g <= g_next;
            h <= h_next;

            // Update the message schedule
            for(i = 0; i < 16; i=i+1) begin
                w[i] <= w_next[i];
            end
            
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