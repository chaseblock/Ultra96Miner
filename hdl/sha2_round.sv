`timescale 1ns / 1ps

// Perform one round of the sha2 algorithm
// This is also refered to as the compression function
module sha2_round(

    // Which round to perform
    input [5:0] round,

    // The corresponding message schedule
    input [31:0] w,

    // Input seed hash values
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [31:0] d,
    input [31:0] e,
    input [31:0] f,
    input [31:0] g,
    input [31:0] h,

    // the results
    output [31:0] a_out,
    output [31:0] b_out,
    output [31:0] c_out,
    output [31:0] d_out,
    output [31:0] e_out,
    output [31:0] f_out,
    output [31:0] g_out,
    output [31:0] h_out
    );

    // The round constants
    wire [31:0] k [0:63] =
         {32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
          32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
          32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
          32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
          32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
          32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
          32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
          32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2};

    // Using the naming from the pseudocode provided on wikipedia
    wire [31:0] e6    = {e[5:0], e[31:6]};
    wire [31:0] e11   = {e[10:0], e[31:11]};
    wire [31:0] e25   = {e[24:0], e[31:25]};
    wire [31:0] S1    = e6 ^ e11 ^ e25;
    wire [31:0] ch    = (e & f) ^ ((~e) & g);
    wire [31:0] _k    = k[round];
    wire [31:0] temp1 = (h + S1) + (ch + _k) + w;
    wire [31:0] a2    = {a[1:0], a[31:2]};
    wire [31:0] a13   = {a[12:0], a[31:13]};
    wire [31:0] a22   = {a[21:0], a[31:22]};
    wire [31:0] S0    = a2 ^ a13 ^ a22;
    wire [31:0] maj   = (a & b) ^ (a & c) ^ (b & c);
    wire [31:0] temp2 = S0 + maj;

    assign h_out = g;
    assign g_out = f;
    assign f_out = e;
    assign e_out = d + temp1;
    assign d_out = c;
    assign c_out = b;
    assign b_out = a;
    assign a_out = temp1 + temp2;

endmodule
