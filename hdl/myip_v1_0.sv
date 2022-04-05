
`timescale 1 ns / 1 ps

	module myip_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 11
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	
	// Assignments:
	// Reg 0: Control
	//     Bit 0 - Reset
	//     Bit 1 - Start
	// Reg 1: Status
	//     Bit 0 - Done
	// Reg 4: Target bits
	// Reg 5: Version
	// Reg 6-13: hashPrevBlock
	// Reg 14-29: hashMerkleRoot
	// Reg 30: timestamp
	// Reg 31: bits
	// Reg 32-39: hash_out
	// Reg 40: nonce_out
	
	wire [31:0] config_regs [511:0];
	
    
    reg process_complete;
    wire [255:0] miner_hash_out;
    reg [255:0] final_hash;
    reg [31:0]  nonce_out;
	
// Instantiation of Axi Bus Interface S00_AXI
	myip_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) myip_v1_0_S00_AXI_inst (
	    .config_regs(config_regs),
	    .hash_out(final_hash),
	    .nonce_out(nonce_out),
	    .miner_done(process_complete),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
	
	reg [31:0] nonce = 0;
	reg start_miner = 0;
	wire miner_done;

    reg reset_miner;
    wire miner_r = config_regs[0][0] || reset_miner;

    miner miner0(
        .clk(s00_axi_aclk),
        .reset(miner_r),
        .start(start_miner),
        .done(miner_done),
        .version(config_regs[7]),
        .hashPrevBlock(256'(config_regs[15:8])),
        .hashMerkleRoot(256'(config_regs[31:16])),
        .timestamp(config_regs[32]),
        .bits(config_regs[33]),
        .nonce(nonce),
        .hash_out(miner_hash_out)
    );

    // Supervisor stuff for the miner
    
    // Count the zeros in the output
    wire [31:0] zeros;
    zero_counter zc(miner_hash_out, zeros);
    
    reg running = 0;
    always @(posedge s00_axi_aclk) begin
        if(config_regs[0][0] == 1'b1) begin// reset logic
            nonce <= 0;
            process_complete <= 0;
            running <= 0;
            reset_miner <= 0;
        end
        else if(config_regs[0][1] && !running) begin // start logic
            running <= 1;
            process_complete <= 0;
            nonce <= 0;
            start_miner <= 1;
            reset_miner <= 0;
        end
        else if(config_regs[0][1] && running) begin
            if(process_complete) begin
                process_complete <= 1;
            end
            else if(miner_done) begin
                // Increment the nonce, unless it's at its maximum
                if(nonce == 32'hFFFFFFFF || zeros > config_regs[4]) begin
                    process_complete <= 1;
                    running <= 0;
                    start_miner <= 0;
                    final_hash <= miner_hash_out;
                    nonce_out <= nonce;
                end
                else begin
                    nonce <= nonce + 1;
                    start_miner <= 1;
                    reset_miner <= 1;
                end
            end
            else begin
                reset_miner <= 0;
            end
        end
    end
    // End supervisor stuff

	// User logic ends

	endmodule
