`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2026 10:17:17 PM
// Design Name: 
// Module Name: encrypt_round
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


module encrypt_round (
    input  wire         last_round,
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);
 
    // ----- SubBytes -----
    wire [127:0] sb_out;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : g_sbox
            aes_sbox u_sb (
                .in_byte (state_in [127 - 8*i -: 8]),
                .out_byte(sb_out   [127 - 8*i -: 8])
            );
        end
    endgenerate
 
    // ----- ShiftRows -----
    wire [127:0] sr_out;

    assign sr_out[127:120] = sb_out[127:120]; 
    assign sr_out[ 95: 88] = sb_out[ 95: 88];
    assign sr_out[ 63: 56] = sb_out[ 63: 56]; 
    assign sr_out[ 31: 24] = sb_out[ 31: 24]; 
 
    assign sr_out[119:112] = sb_out[ 87: 80];
    assign sr_out[ 87: 80] = sb_out[ 55: 48]; 
    assign sr_out[ 55: 48] = sb_out[ 23: 16]; 
    assign sr_out[ 23: 16] = sb_out[119:112]; 

    assign sr_out[111:104] = sb_out[ 47: 40]; 
    assign sr_out[ 79: 72] = sb_out[ 15:  8]; 
    assign sr_out[ 47: 40] = sb_out[111:104]; 
    assign sr_out[ 15:  8] = sb_out[ 79: 72]; 
 
    assign sr_out[103: 96] = sb_out[  7:  0]; 
    assign sr_out[ 71: 64] = sb_out[103: 96]; 
    assign sr_out[ 39: 32] = sb_out[ 71: 64]; 
    assign sr_out[  7:  0] = sb_out[ 39: 32]; 
 
    // ----- MixColumns -----
    wire [127:0] mc_out;
    mixcolumns u_mc (
        .state_in (sr_out),
        .state_out(mc_out)
    );
 
    // ----- AddRoundKey -----
    wire [127:0] pre_ark = last_round ? sr_out : mc_out;
    assign state_out = pre_ark ^ round_key;
 
endmodule 
