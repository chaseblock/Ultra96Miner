`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2022 02:34:16 PM
// Design Name: 
// Module Name: miner_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TOP();

    // Run the bitcoin mining test
    SUPERVISOR_TEST test();
//    MINER_TEST test();

    initial #100000 $finish;

endmodule

module SUPERVISOR_TEST();

    reg clk;
    initial clk <= 0;
    always #5 clk <= ~clk;
    
    reg reset, start;
    wire done;
    
    reg [4*8  - 1: 0] version;
    reg [32*8 - 1: 0] hashPrevBlock;
    reg [32*8 - 1: 0] hashMerkleRoot;
    reg [4*8  - 1: 0] timestamp;
    reg [4*8  - 1: 0] bits;
//    reg [4*8  - 1: 0] nonce; // Not used: for the supervisor to generate
    
    wire [31:0] target_bits = 16;
    wire success;
    wire [255:0] hash_out;
    wire [31:0] nonce_out;
    
    // Module under test
    multi_supervisor #(2) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        
        .version(version), // config_regs[7]
        .hashPrevBlock(hashPrevBlock), // 256'(config_regs[15:8])
        .hashMerkleRoot(hashMerkleRoot), // 256'(config_regs[31:16])
        .timestamp(timestamp), // config_regs[32]
        .bits(bits), // config_regs[33]
        .target_bits(target_bits), // config_regs[4]
        
        .process_complete(done),
        .hash_out(hash_out),
        .nonce_out(nonce_out),
        .success(success)
    );
    
    initial begin
        // Reset the supervisor
        start = 0;
        reset = 1;
        
        @(posedge clk);
        @(posedge clk);
        
        // Set up the data to be hashed
        version = 32'h01;
        hashPrevBlock  = 256'h00000000000008a3a41b85b8b29ad444def299fee21793cd8b9e567eab02cd81;
        hashMerkleRoot = 256'h2b12fcf1b09288fcaff797d71e950e71ae42b91e8bdb2304758dfcffc2b620e3;
        timestamp = 32'd1305998791;
        bits = 32'd440711666;
        
        // De-assert the reset signal and start the miners
        reset = 0;
        start = 1;
        
        @(posedge clk);
        
        // Because we don't want to wait forever to let it find the correct answer,
        // we're going to sneak in an set its nonce value to a closer answer
        uut.nonce <= 32'd2504433986 - 5;
        
        @(posedge clk);
        
        // Wait for the supervisor to report completion
        @(done);
        
        // Delay for a bit longer, then end
        #50;
        $finish;
    end

endmodule

module MINER_TEST();

    reg clk;
    initial clk <= 0;
    always #5 clk <= ~clk;

    reg reset, start;
    wire done;

    reg [4*8 - 1: 0] version;
    reg [32*8 - 1: 0] hashPrevBlock;
    reg [32*8 - 1: 0] hashMerkleRoot;
    reg [4*8 - 1: 0] timestamp;
    reg [4*8 - 1: 0] bits;
    reg [4*8 - 1: 0] nonce;

    reg [255:0] hash;

    // The module under test
    miner uut(
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),

        .version(version),
        .hashPrevBlock(hashPrevBlock),
        .hashMerkleRoot(hashMerkleRoot),
        .timestamp(timestamp),
        .bits(bits),
        .nonce(nonce),

        .hash_out(hash)
    );

    initial begin
        // Reset everything
        start = 0;
        reset = 1;

        @(posedge clk);
        @(posedge clk);

        // Set up the data to be hashed
        
        // Big endian version
        version = 32'h01;
        hashPrevBlock  = 256'h00000000000008a3a41b85b8b29ad444def299fee21793cd8b9e567eab02cd81;
        hashMerkleRoot = 256'h2b12fcf1b09288fcaff797d71e950e71ae42b91e8bdb2304758dfcffc2b620e3;
        timestamp = 32'd1305998791;
        bits = 32'd440711666;
        nonce = 32'd2504433986;
        
        @(posedge clk);

        start = 1;
        reset = 0;

        @(posedge clk);

        // Wait for the system to finish
        @(done);

        // Delay a bit longer, and then terminate the test
        #50;
        $finish;

    end

endmodule