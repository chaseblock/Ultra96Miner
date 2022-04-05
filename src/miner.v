`timescale 1 ns / 1 ps

// Expects all data in big-endian format. It internally uses little-endian (kinda),
// but whatever. It's all the same at the hardware level. If we need to change
// this later, then we will.
// The output is also in big endian format.
module miner(
    input clk,
    input reset,
    input start,
    output done,

    input [4*8 - 1: 0] version,
    input [32*8 - 1: 0] hashPrevBlock,
    input [32*8 - 1: 0] hashMerkleRoot,
    input [4*8 - 1: 0] timestamp,
    input [4*8 - 1: 0] bits,
    input [4*8 - 1: 0] nonce,

    output [255:0] hash_out
    );

    // Arrange the data in the proper format for hashing
    // First we'll arrange all of the input data into 
    // a single unit backwards, then turn it into little
    // endian encoding, then pad and prepare for hashing
    wire [80*8 - 1 : 0] msg_bigend = {
        nonce,
        bits,
        timestamp,
        hashMerkleRoot,
        hashPrevBlock,
        version
    };

    // Convert to little endian
    wire [80*8 - 1 : 0] msg_littleend;
    genvar i;
    generate
        for(i = 0; i < 80; i=i+1) begin: endian_loop
            assign msg_littleend[i*8 +: 8] = msg_bigend[(80*8-1) - i*8 -: 8];
        end
    endgenerate

    // Now we pad the resultant message to prepare for hashing
    wire [1023:0] msg = {
        msg_littleend,
        // msg_bigend,
        1'b1,
        319'b0,
        64'd640
    };

    // Instantiate two hashers. These will each compute part of
    // our problem.
    reg start1;
    wire reset1, done1;
    wire [255:0] hash1;
    sha256 #(2) sha1(
        clk,
        reset1,
        start1,
        done1,
        msg,
        hash1
    );

    reg start2;
    wire reset2, done2;
    wire [255:0] hash2;
    sha256 #(1) sha2(
        clk,
        reset2,
        start2,
        done2,
        {hash1, 1'b1, 191'b0, 64'd256},
        hash2
    );

    // Convert the output hash to big endian for the output
    generate
        for(i = 0; i < 32; i=i+1) begin: out_endian_loop
            assign hash_out[i*8 +: 8] = hash2[(32*8-1) - i*8 -: 8];
        end
    endgenerate

    reg running;

    assign reset1 = reset;
    assign reset2 = reset;
    assign done = done1 && done2;

    always @(posedge clk) begin
        if(reset && !start) begin
            // Handle reset
            running <= 1'b0;
            start1 <= 1'b0;
            start2 <= 1'b0;
        end
        else if(start && ((!running && !done) || reset)) begin
            // Start the computation
            running <= 1'b1;
            start1 <= 1'b1;
            start2 <= 1'b0;
        end
        else if(start && running && !done) begin
            // Handle the continuing computation
            
            if(!done1) begin
                // The first hasher is not yet done, so we need to
                // let it keep running.
                // There's not really anything to do here.
            end
            else begin
                // The first computation is done, so we need to keep
                // the second one running
                start2 <= 1'b1;
            end
        end
        else if (!start) begin
            // Handle the stop condition
            running <= 0;
            start1 <= 0;
            start2 <= 0;
        end
    end

endmodule