`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2026 04:24:20 PM
// Design Name: 
// Module Name: key_expansion
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


module key_expansion (
    input  wire [127:0] key_in,    
    input  wire [3:0]   round,    
    output wire [127:0] key_out   
);
 
    wire [31:0] w0 = key_in[127:96];
    wire [31:0] w1 = key_in[ 95:64];
    wire [31:0] w2 = key_in[ 63:32];
    wire [31:0] w3 = key_in[ 31: 0];
    //RotWord - dich trai 1 byte
    wire [31:0] rot_w3 = {w3[23:0], w3[31:24]};
    //SubWord - S_box cho tung byte
    wire [7:0] sb0, sb1, sb2, sb3;
    aes_sbox u_sb_k0 (.in_byte(rot_w3[31:24]), .out_byte(sb0));
    aes_sbox u_sb_k1 (.in_byte(rot_w3[23:16]), .out_byte(sb1));
    aes_sbox u_sb_k2 (.in_byte(rot_w3[15: 8]), .out_byte(sb2));
    aes_sbox u_sb_k3 (.in_byte(rot_w3[ 7: 0]), .out_byte(sb3));
 
    wire [31:0] sub_rot_w3 = {sb0, sb1, sb2, sb3};
 
    reg [7:0] rcon;
    always @(*) begin
        case (round)
            4'd1:  rcon = 8'h01;
            4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04;
            4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10;
            4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40;
            4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1b;
            4'd10:  rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    end
    //Xor Rcon
    wire [31:0] rcon32 = {rcon, 24'h0};
    // g_w3 = SubWord(RotWord(w3)) XOR Rcon
    wire [31:0] g_w3   = sub_rot_w3 ^ rcon32;
 
    wire [31:0] new_w0 = w0 ^ g_w3;
    wire [31:0] new_w1 = w1 ^ new_w0;
    wire [31:0] new_w2 = w2 ^ new_w1;
    wire [31:0] new_w3 = w3 ^ new_w2;
 
    assign key_out = {new_w0, new_w1, new_w2, new_w3};
 
endmodule 
