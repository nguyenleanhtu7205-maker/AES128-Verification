`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2026 04:07:18 PM
// Design Name: 
// Module Name: mixcolumns
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


module mixcolumns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : col
            wire [7:0] a0, a1, a2, a3;  //4 byte input cua cot thu c
            wire [7:0] b0, b1, b2, b3;  //4 byte output cua cot thu c
            wire [7:0] tmp, tm;
			//4 bytes cot c	
            assign a0 = state_in[127 - 8*(4*c + 0) -: 8];
            assign a1 = state_in[127 - 8*(4*c + 1) -: 8];
            assign a2 = state_in[127 - 8*(4*c + 2) -: 8];
            assign a3 = state_in[127 - 8*(4*c + 3) -: 8];

            assign tmp = a0 ^ a1 ^ a2 ^ a3;

            wire [7:0] x01 = a0 ^ a1;
            wire [7:0] x12 = a1 ^ a2;
            wire [7:0] x23 = a2 ^ a3;
            wire [7:0] x30 = a3 ^ a0;
            
            //Ham xtime (nhan 2 trong GF) cho hai so
            wire [7:0] xt01 = {x01[6:0], 1'b0} ^ (x01[7] ? 8'h1b : 8'h00);
            wire [7:0] xt12 = {x12[6:0], 1'b0} ^ (x12[7] ? 8'h1b : 8'h00);
            wire [7:0] xt23 = {x23[6:0], 1'b0} ^ (x23[7] ? 8'h1b : 8'h00);
            wire [7:0] xt30 = {x30[6:0], 1'b0} ^ (x30[7] ? 8'h1b : 8'h00);

            assign b0 = a0 ^ tmp ^ xt01; //b0 = a0 ^ (a0 ^ a1 ^ a2 ^ a3) ^ (2(x01)) = 2a0 ^ 3a1 ^ a2 ^ a3
            assign b1 = a1 ^ tmp ^ xt12;
            assign b2 = a2 ^ tmp ^ xt23;
            assign b3 = a3 ^ tmp ^ xt30;

            assign state_out[127 - 8*(4*c + 0) -: 8] = b0;
            assign state_out[127 - 8*(4*c + 1) -: 8] = b1;
            assign state_out[127 - 8*(4*c + 2) -: 8] = b2;
            assign state_out[127 - 8*(4*c + 3) -: 8] = b3;
        end
    endgenerate

endmodule 
