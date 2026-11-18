`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 11:00:35 PM
// Design Name: 
// Module Name: inv_key_expansion
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


module inv_key_expansion (
    input  wire [127:0] key_in,    
    input  wire [3:0]   round,     
    output wire [127:0] key_out    
);

    wire [31:0] kr_w0 = key_in[127:96];
    wire [31:0] kr_w1 = key_in[ 95:64];
    wire [31:0] kr_w2 = key_in[ 63:32];
    wire [31:0] kr_w3 = key_in[ 31: 0];
    
    //Khoi phuc w1, w2, w3 cua round truoc
    wire [31:0] km1_w3 = kr_w3 ^ kr_w2;
    wire [31:0] km1_w2 = kr_w2 ^ kr_w1;
    wire [31:0] km1_w1 = kr_w1 ^ kr_w0;

    //Tinh g(km1_w3) de khoi phuc w0 cua round truoc
    wire [31:0] rot_w3 = {km1_w3[23:0], km1_w3[31:24]};

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

    wire [31:0] g_w3   = sub_rot_w3 ^ {rcon, 24'h0};
    wire [31:0] km1_w0 = kr_w0 ^ g_w3;

    assign key_out = {km1_w0, km1_w1, km1_w2, km1_w3};

endmodule  
