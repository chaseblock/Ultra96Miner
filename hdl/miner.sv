`timescale 1 ns / 1 ps

// Expects all data in big-endian format. It internally uses little-endian (kinda),
// but whatever. It's all the same at the hardware level. If we need to change
// this later, then we will.
// The output is also in big endian format.
module miner(
    input clk,
    input reset,
    input start,
    output reg done,

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
    wire [1023:0] input_msg = {
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
    wire [255:0] hash_result;
    reg [1023:0] msg;
    reg [1:0] num_chunks;
    sha256 #(2) sha1(
        clk,
        reset1,
        start1,
        done1,
        num_chunks,
        msg,
        hash_result
    );

    // Convert the output hash to big endian for the output
    generate
        for(i = 0; i < 32; i=i+1) begin: out_endian_loop
            assign hash_out[i*8 +: 8] = hash_result[(32*8-1) - i*8 -: 8];
        end
    endgenerate

    reg running1;
    reg running2;

    reg reset_sha;
    assign reset1 = reset || reset_sha;

    always @(posedge clk) begin
        if(reset) begin
            // Handle reset
            running1 <= 1'b0;
            running2 <= 1'b0;
            start1 <= 1'b0;
            done <= 1'b0;
            reset_sha <= 1'b0;
        end
        else if(start && ((!running1 && !running2 && !done) || reset)) begin
            // Start the computation
            running1 <= 1'b1;
            running2 <= 1'b0;
            start1 <= 1'b1;
            msg <= input_msg;
            num_chunks <= 2;
            reset_sha <= 1'b0;
        end
        else if(start && (running1 || running2) && !done) begin
            // Handle the continuing computation
            
            if(!done1 && running1) begin
                // The first hasher is not yet done, so we need to
                // let it keep running.
                // There's not really anything to do here.
                start1 <= 1;
            end
            else if(!running2) begin
                // The first computation is done, so we need to start
                // the second computation
                running1 <= 0;
                running2 <= 1;
                start1 <= 0;
                reset_sha <= 1;
                num_chunks <= 1;
                msg <= {hash_result, 1'b1, 191'b0, 64'd256, 512'bx};
            end
            else if(running2) begin
                // Keep the last computation running
                start1 <= 1;
                reset_sha <= 0;
                done <= done1 && !reset_sha;
            end
        end
        else if (!start) begin
            // Handle the stop condition
            running1 <= 0;
            running2 <= 0;
            start1 <= 0;
        end
    end

endmodule

// Expects all data in big-endian format. It internally uses little-endian (kinda),
// but whatever. It's all the same at the hardware level. If we need to change
// this later, then we will.
// The output is also in big endian format.
module varminer #(parameter NUM_HASHERS = 1) (
    input clk,
    input reset,
    input start,
    output reg done,

    input [4*8 - 1: 0] version,
    input [32*8 - 1: 0] hashPrevBlock,
    input [32*8 - 1: 0] hashMerkleRoot,
    input [4*8 - 1: 0] timestamp,
    input [4*8 - 1: 0] bits,
    input [4*8 - 1: 0] nonce [NUM_HASHERS - 1: 0],

    output [255:0] hash_out [NUM_HASHERS - 1: 0]
    );

    // Arrange the data in the proper format for hashing
    // First we'll arrange all of the input data into 
    // a single unit backwards, then turn it into little
    // endian encoding, then pad and prepare for hashing
    wire [80*8 - 1 : 0] msg_bigend [NUM_HASHERS - 1 : 0];
    genvar i;
    generate
        for(i = 0; i < NUM_HASHERS; i = i + 1) begin: msg_loop
            assign msg_bigend[i] = {
                nonce[i],
                bits,
                timestamp,
                hashMerkleRoot,
                hashPrevBlock,
                version
            };
        end
    endgenerate

    // Convert to little endian
    wire [80*8 - 1 : 0] msg_littleend [NUM_HASHERS - 1: 0];
    genvar j;
    generate
        for(j = 0; j < NUM_HASHERS; j = j + 1) begin: endian_loop0
            for(i = 0; i < 80; i=i+1) begin: endian_loop
                assign msg_littleend[j][i*8 +: 8] = msg_bigend[j][(80*8-1) - i*8 -: 8];
            end
        end
    endgenerate

    // Now we pad the resultant message to prepare for hashing
    wire [1023:0] input_msg [NUM_HASHERS - 1 : 0];
    generate
        for(i = 0; i < NUM_HASHERS; i = i + 1) begin: input_loop
            assign input_msg[i] = {
                msg_littleend[i],
                // msg_bigend,
                1'b1,
                319'b0,
                64'd640
            };
        end
    endgenerate
    

    // Instantiate the hashers. These will each compute part of
    // our problem.
    reg start1;
    wire [NUM_HASHERS-1:0] done_sigs;
    wire reset1, done1;
    assign done1 = done_sigs[0];
    wire [255:0] hash_result [NUM_HASHERS - 1: 0];
    reg [1023:0] msg [NUM_HASHERS - 1: 0];
    reg [1:0] num_chunks;
    
    generate
        for(i = 0; i < NUM_HASHERS; i = i + 1) begin: sha1_loop
            sha256 #(2) sha1(
                clk,
                reset1,
                start1,
                done_sigs[i],
                num_chunks,
                msg[i],
                hash_result[i]
            );
        end
    endgenerate

    // Convert the output hash to big endian for the output
    generate
        for(j = 0; j < NUM_HASHERS; j = j + 1) begin: out_endian_loop0
            for(i = 0; i < 32; i=i+1) begin: out_endian_loop
                assign hash_out[j][i*8 +: 8] = hash_result[j][(32*8-1) - i*8 -: 8];
            end
        end
    endgenerate

    reg running1;
    reg running2;

    reg reset_sha;
    assign reset1 = reset || reset_sha;

    always @(posedge clk) begin
        if(reset) begin
            // Handle reset
            running1 <= 1'b0;
            running2 <= 1'b0;
            start1 <= 1'b0;
            done <= 1'b0;
            reset_sha <= 1'b0;
        end
        else if(start && ((!running1 && !running2 && !done) || reset)) begin
            // Start the computation
            running1 <= 1'b1;
            running2 <= 1'b0;
            start1 <= 1'b1;
            msg <= input_msg;
            num_chunks <= 2;
            reset_sha <= 1'b0;
        end
        else if(start && (running1 || running2) && !done) begin
            // Handle the continuing computation
            
            if(!done1 && running1) begin
                // The first hasher is not yet done, so we need to
                // let it keep running.
                // There's not really anything to do here.
                start1 <= 1;
            end
            else if(!running2) begin
                // The first computation is done, so we need to start
                // the second computation
                running1 <= 0;
                running2 <= 1;
                start1 <= 0;
                reset_sha <= 1;
                num_chunks <= 1;
                begin
                    integer k;
                    for(k = 0; k < NUM_HASHERS; k = k + 1)
                        msg[k] <= {hash_result[k], 1'b1, 191'b0, 64'd256, 512'bx};
                end
            end
            else if(running2) begin
                // Keep the last computation running
                start1 <= 1;
                reset_sha <= 0;
                done <= done1 && !reset_sha;
            end
        end
        else if (!start) begin
            // Handle the stop condition
            running1 <= 0;
            running2 <= 0;
            start1 <= 0;
        end
    end

endmodule