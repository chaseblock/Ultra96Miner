`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2022 04:21:37 PM
// Design Name: 
// Module Name: zero_counter
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


module zero_counter(
    input [255:0] hash,
    
    output [31:0] num_zeros
    );
    
    integer c;
    integer i;
    reg done;
    always @(*) begin
        done = 0;
        c = 0;
        i = 0;
        
        for(i=0; i<256; i=i+1) begin
            if(hash[255-i] == 0 && !done)
                c = c + 1;
            else
                done = 1;
        end
    end
    
    assign num_zeros = c;
    
endmodule
