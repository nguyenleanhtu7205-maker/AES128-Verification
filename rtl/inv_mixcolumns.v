`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 10:58:45 PM
// Design Name: 
// Module Name: inv_mixcolumns
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


module inv_mixcolumns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    //Ham xtiem (nhan 2)
    function [7:0] xt;
        input [7:0] b;
        begin
            xt = {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
        end
    endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : col
            wire [7:0] a0, a1, a2, a3;

            assign a0 = state_in[127 - 8*(4*c + 0) -: 8];
            assign a1 = state_in[127 - 8*(4*c + 1) -: 8];
            assign a2 = state_in[127 - 8*(4*c + 2) -: 8];
            assign a3 = state_in[127 - 8*(4*c + 3) -: 8];

            wire [7:0] a0_2 = xt(a0);
            wire [7:0] a0_4 = xt(a0_2);
            wire [7:0] a0_8 = xt(a0_4);
            wire [7:0] a1_2 = xt(a1);
            wire [7:0] a1_4 = xt(a1_2);
            wire [7:0] a1_8 = xt(a1_4);
            wire [7:0] a2_2 = xt(a2);
            wire [7:0] a2_4 = xt(a2_2);
            wire [7:0] a2_8 = xt(a2_4);
            wire [7:0] a3_2 = xt(a3);
            wire [7:0] a3_4 = xt(a3_2);
            wire [7:0] a3_8 = xt(a3_4);
            
            //Hang 0
            wire [7:0] e_a0 = a0_8 ^ a0_4 ^ a0_2;   //14a0
            wire [7:0] b_a1 = a1_8 ^ a1_2 ^ a1;     //11a1
            wire [7:0] d_a2 = a2_8 ^ a2_4 ^ a2;     //13a2
            wire [7:0] n_a3 = a3_8 ^ a3;            //9a3

            //Hang 1
            wire [7:0] n_a0 = a0_8 ^ a0;            //9a0
            wire [7:0] e_a1 = a1_8 ^ a1_4 ^ a1_2;   //14a1
            wire [7:0] b_a2 = a2_8 ^ a2_2 ^ a2;     //11a2
            wire [7:0] d_a3 = a3_8 ^ a3_4 ^ a3;     //13a3

            //Hang 2
            wire [7:0] d_a0 = a0_8 ^ a0_4 ^ a0;     //13a0
            wire [7:0] n_a1 = a1_8 ^ a1;            //9a1
            wire [7:0] e_a2 = a2_8 ^ a2_4 ^ a2_2;   //14a2
            wire [7:0] b_a3 = a3_8 ^ a3_2 ^ a3;     //11a3

            //Hang 3
            wire [7:0] b_a0 = a0_8 ^ a0_2 ^ a0;     //11a0
            wire [7:0] d_a1 = a1_8 ^ a1_4 ^ a1;     //13a1
            wire [7:0] n_a2 = a2_8 ^ a2;            //9a2
            wire [7:0] e_a3 = a3_8 ^ a3_4 ^ a3_2;   //14a3

            wire [7:0] b0 = e_a0 ^ b_a1 ^ d_a2 ^ n_a3;
            wire [7:0] b1 = n_a0 ^ e_a1 ^ b_a2 ^ d_a3;
            wire [7:0] b2 = d_a0 ^ n_a1 ^ e_a2 ^ b_a3;
            wire [7:0] b3 = b_a0 ^ d_a1 ^ n_a2 ^ e_a3;

            assign state_out[127 - 8*(4*c + 0) -: 8] = b0;
            assign state_out[127 - 8*(4*c + 1) -: 8] = b1;
            assign state_out[127 - 8*(4*c + 2) -: 8] = b2;
            assign state_out[127 - 8*(4*c + 3) -: 8] = b3;
        end
    endgenerate

endmodule 
