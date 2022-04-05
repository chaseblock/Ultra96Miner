`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2022 03:22:47 PM
// Design Name: 
// Module Name: multi_supervisor
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


module multi_supervisor #(parameter NUM_MINERS=1) (
    input clk,
    input reset,    // config_regs[0][0]
    input start,    // config_regs[0][1]
    
    input [31:0] version, // config_regs[7]
    input [255:0] hashPrevBlock, // 256'(config_regs[15:8])
    input [255:0] hashMerkleRoot, // 256'(config_regs[31:16])
    input [31:0] timestamp, // config_regs[32]
    input [31:0] bits, // config_regs[33]
    input [31:0] target_bits, // config_regs[4]
    
    output reg process_complete,
    output reg [255:0] hash_out,
    output reg [31:0] nonce_out,
    output reg success
    );
	
	// Inputs to the miners
	reg [31:0] nonce;
	reg start_miners;
	reg reset_miners;
    wire miner_r = reset || reset_miners;
	
	// The outputs of the miners
	wire miner_done [NUM_MINERS-1:0];
	wire [255:0] miner_hash_out [NUM_MINERS-1:0];

    // Instantiate all of the miners that we'll be needing
    `define num_miner_bits $clog2(NUM_MINERS)
    `define max_nonce (32'hFFFF_FFFF >> `num_miner_bits)
    genvar i;
    generate
        for(i = 0; i < NUM_MINERS; i=i+1) begin: miner_loop
            miner m(
                .clk(clk),
                .reset(miner_r),
                .start(start_miners),
                .done(miner_done[i]),
                .version(version),
                .hashPrevBlock(hashPrevBlock),
                .hashMerkleRoot(hashMerkleRoot),
                .timestamp(timestamp),
                .bits(bits),
                .nonce({`num_miner_bits'(i), nonce[0 +: (31-`num_miner_bits)]}),
                .hash_out(miner_hash_out[i])
            );
        end
    endgenerate
    
    // Create the control logic for the miners
    reg running = 0;
    reg [255:0] miners_last_hash [NUM_MINERS-1:0];
    reg [31:0] miners_last_nonce [NUM_MINERS-1:0];
    
    // Seperate logic for logging all of the results of the mining units
    generate
        for(i = 0; i < NUM_MINERS; i=i+1) begin: control_loop
            
            // Check for the thing being finished
            always @(posedge clk) begin: control_loop2
                if(start && running && miner_done[i]) begin
                    miners_last_hash[i] <= miner_hash_out[i];
                    miners_last_nonce[i] <= {`num_miner_bits'(i), nonce[0 +: (31-`num_miner_bits)]};
                end
            end
        end
    endgenerate
    
    // Count the zeros in the output
    reg [`num_miner_bits : 0] current_evaluation;
    wire [31:0] zeros;
    zero_counter zc(miners_last_hash[`num_miner_bits'(current_evaluation)], zeros);
    reg enable_cmp;
    reg [31:0] last_zero_count;
    always @(posedge clk) last_zero_count <= zeros;
    
    // Common control logic
    always @(posedge clk) begin
        if(reset == 1'b1) begin// reset logic (config_regs[0][0])
            nonce <= 0;
            process_complete <= 0;
            running <= 0;
            reset_miners <= 0;
            enable_cmp <= 0;
            current_evaluation <= `num_miner_bits'(0);
        end
        else if(start && !running) begin // start logic (config_regs[0][1])
            running <= 1;
            process_complete <= 0;
            nonce <= 0;
            start_miners <= 1;
            reset_miners <= 0;
        end
        else if(start && running) begin
        
            // If we've already finished, just wait until we are reset
            if(process_complete) begin
                process_complete <= 1;
            end
            
            // If the miners are done, move on to the next iteration
            // Since the miners move in lockstep, checking one for being
            // done is enough.
            else if(miner_done[0]) begin
            
                // Start the comparison logic on the next clock cycle
                enable_cmp <= 1;
                current_evaluation <= `num_miner_bits'(0);
            
                // Increment the nonce, unless it's at its maximum
                if(nonce == `max_nonce) begin
                    process_complete <= 1;
                    start_miners <= 0;
                    nonce_out <= nonce;
                end
                else begin
                    nonce <= nonce + 1;
                    start_miners <= 1;
                    reset_miners <= 1;
                end
            end
            
            // Otherwise, just keep the miners running
            else begin
                reset_miners <= 0;
            end
        end
        
        // Run comparison logic to determine whether or not we need to report a success
        if(enable_cmp && !reset && running) begin
        
            if(last_zero_count >= target_bits) begin
                process_complete <= 1;
                start_miners <= 0;
                nonce_out <= {`num_miner_bits'(current_evaluation - 1), nonce[0 +: (31-`num_miner_bits)]};
                hash_out <= miners_last_hash[current_evaluation - 1];
                enable_cmp <= 0;
                current_evaluation <= 0;
            end
            else begin
                current_evaluation <= current_evaluation + 1;
                if({1'b0, current_evaluation} + 1 > NUM_MINERS) begin
                    enable_cmp <= 0;
                end
            end
        end
    end
endmodule
