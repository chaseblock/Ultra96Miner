`timescale 1ns / 1ps

// A sha256 core. We will assume that the message has already been padded by the time it gets here.
module sha256
    #(parameter MAX_CHUNKS = 1)
    (
    input clk,
    input reset,
    // Will run as long as this is held high
    input start,
    output reg done,
    input [$clog2(MAX_CHUNKS):0] num_chunks,

    // Must be aligned to the highest-order bits
    input [MAX_CHUNKS*512 - 1:0] str,

    output [255:0] hash
    );

    // Constant hash starting values
    wire [31:0] h0_start = 32'h6a09e667;
    wire [31:0] h1_start = 32'hbb67ae85;
    wire [31:0] h2_start = 32'h3c6ef372;
    wire [31:0] h3_start = 32'ha54ff53a;
    wire [31:0] h4_start = 32'h510e527f;
    wire [31:0] h5_start = 32'h9b05688c;
    wire [31:0] h6_start = 32'h1f83d9ab;
    wire [31:0] h7_start = 32'h5be0cd19;

    // Temporary hash registers
    reg [31:0] h0;
    reg [31:0] h1;
    reg [31:0] h2;
    reg [31:0] h3;
    reg [31:0] h4;
    reg [31:0] h5;
    reg [31:0] h6;
    reg [31:0] h7;

    // The output hash is just a concatenation of all of the
    // smaller hashes
    assign hash = {h0, h1, h2, h3, h4, h5, h6, h7};

    // Control lines
    reg start_chunk;
    wire reset_chunk = reset;

    reg [1:0] chunk_num; // Only support up to 3 chunks right now.
    reg [511:0] chunk_data;

    always @(*) begin
        // chunk_data = str[512*chunk_num +: 512];
        chunk_data = str[(512*MAX_CHUNKS-1) - (512*chunk_num) -: 512];
    end

    // Our computation engine
    wire [31:0] h0_next, h1_next, h2_next, h3_next,
                h4_next, h5_next, h6_next, h7_next;
    wire chunk_complete;
    sha2_chunk chunker(
        .clk(clk),
        // Control lines
        .start(start_chunk),
        .reset(reset_chunk),
        .chunk(chunk_data),
        // Input data
        .h0(h0), .h1(h1), .h2(h2), .h3(h3),
        .h4(h4), .h5(h5), .h6(h6), .h7(h7),
        // Output data
        .h0_out(h0_next), .h1_out(h1_next), .h2_out(h2_next), 
        .h3_out(h3_next), .h4_out(h4_next), .h5_out(h5_next), 
        .h6_out(h6_next), .h7_out(h7_next),
        // Final control output 
        .done(chunk_complete)
    );

    reg running;

    always @(posedge clk) begin
        if(reset) begin
            // Handle reset condition
            done <= 1'b0;
            running <= 1'b0;
            start_chunk <= 1'b0;
            chunk_num <= 0;
        end
        else if (start && !running && !done) begin
            // Start the computation. We'll actually start
            // processing the sha256 hash in the next clock
            // cycle.
            running <= 1'b1;

            h0 <= h0_start;
            h1 <= h1_start;
            h2 <= h2_start;
            h3 <= h3_start;
            h4 <= h4_start;
            h5 <= h5_start;
            h6 <= h6_start;
            h7 <= h7_start;
        end
        else if (start && running && !done) begin
            
            if(!start_chunk) begin
                // We aren't currently running a chunk,
                // so we should start it.
                start_chunk <= 1'b1;
            end
            else if(chunk_complete) begin
                // The chunk finished, so we should update
                // our hash and start the next chunk.
                // We'll update our stuff, and then start the
                // next chunk on the next cycle.
                chunk_num <= chunk_num + 1'b1;
                start_chunk <= 1'b0;

                h0 <= h0_next;
                h1 <= h1_next;
                h2 <= h2_next;
                h3 <= h3_next;
                h4 <= h4_next;
                h5 <= h5_next;
                h6 <= h6_next;
                h7 <= h7_next;
                
                // If that was the last chunk, then end the
                // process.
                if(chunk_num + 1'b1 == num_chunks) begin
                    running <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
        else if(!start) begin
            done <= 0;
            running <= 0;
        end
    end

endmodule
