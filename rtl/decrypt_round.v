`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 11:03:20 PM
// Design Name: 
// Module Name: decrypt_round
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


module decrypt_round (
    input  wire         last_round,
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);

    // ----- InvShiftRows -----
    wire [127:0] isr_out;

    assign isr_out[127:120] = state_in[127:120];
    assign isr_out[ 95: 88] = state_in[ 95: 88];
    assign isr_out[ 63: 56] = state_in[ 63: 56];
    assign isr_out[ 31: 24] = state_in[ 31: 24];

    assign isr_out[119:112] = state_in[ 23: 16]; 
    assign isr_out[ 87: 80] = state_in[119:112]; 
    assign isr_out[ 55: 48] = state_in[ 87: 80]; 
    assign isr_out[ 23: 16] = state_in[ 55: 48]; 

    assign isr_out[111:104] = state_in[ 47: 40]; 
    assign isr_out[ 79: 72] = state_in[ 15:  8]; 
    assign isr_out[ 47: 40] = state_in[111:104]; 
    assign isr_out[ 15:  8] = state_in[ 79: 72]; 

    assign isr_out[103: 96] = state_in[ 71: 64]; 
    assign isr_out[ 71: 64] = state_in[ 39: 32]; 
    assign isr_out[ 39: 32] = state_in[  7:  0]; 
    assign isr_out[  7:  0] = state_in[103: 96]; 

    // ----- InvSubBytes -----
    wire [127:0] isb_out;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : g_isb
            aes_inv_sbox u_isb (
                .in_byte (isr_out[127 - 8*i -: 8]),
                .out_byte(isb_out[127 - 8*i -: 8])
            );
        end
    endgenerate

    // ----- AddRoundKey -----
    wire [127:0] ark_out = isb_out ^ round_key;

    // ----- InvMixColumns (skipped in last round) -----
    wire [127:0] imc_out;
    inv_mixcolumns u_imc (
        .state_in (ark_out),
        .state_out(imc_out)
    );

    assign state_out = last_round ? ark_out : imc_out;

endmodule 
