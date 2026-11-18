`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/23/2026 12:01:46 AM
// Design Name: 
// Module Name: aes128_top
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


module aes128_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         mode,        // 0=encrypt, 1=decrypt
    input  wire [127:0] data_in,
    input  wire [127:0] key,
    output wire [127:0] data_out,
    output wire         done,
    output wire         busy
);

    wire [127:0] enc_out, dec_out;
    wire         enc_done, dec_done;
    wire         enc_busy, dec_busy;

    //Chi nhan start khi ca hai loi deu ranh
    wire start_valid = start && !busy;

    reg mode_reg;
    always @(posedge clk) begin
      if (!rst_n)
        mode_reg <= 1'b0;
      else if (start_valid)
        mode_reg <= mode;
    end 

    aes128_encrypt u_enc (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start_valid && !mode),
        .plaintext (data_in),
        .key       (key),
        .ciphertext(enc_out),
        .done      (enc_done),
        .busy      (enc_busy)
    );

    aes128_decrypt u_dec (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start_valid &&  mode),
        .ciphertext(data_in),
        .key       (key),
        .plaintext (dec_out),
        .done      (dec_done),
        .busy      (dec_busy)
    );

    wire [127:0] selected_out = mode_reg ? dec_out      : enc_out;
    assign       data_out     = done     ? selected_out : 128'b0;
    assign       done         = mode_reg ? dec_done     : enc_done;
    assign       busy         = enc_busy | dec_busy;

endmodule  
