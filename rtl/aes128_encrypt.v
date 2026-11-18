`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2026 10:27:00 PM
// Design Name: 
// Module Name: aes128_encrypt
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


module aes128_encrypt (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done,
    output wire         busy
);

    // ---- FSM ---------------------------------------------------------------
    reg [3:0] round_cnt;              
    wire      idle       = (round_cnt == 4'h0); //Tramg thai khoi tao
    wire      last_round = (round_cnt == 4'd10);//Vong cuoi cung (vong 10)
    assign    busy       = ~idle;

    // ---- output registers ----------------------------------------------
    reg [127:0] state_reg;  //state sau round vua roi
    reg [127:0] key_reg;    //round key vua dung                

    // ---- Round-input  -----------------------------------------
    wire [127:0] round_in_state = idle ? (plaintext ^ key) : state_reg;
    wire [127:0] keyx_in        = idle ? key               : key_reg;
    wire [3:0]   keyx_round_idx = idle ? 4'd1              : (round_cnt);

    wire [127:0] next_key;
    key_expansion u_keyx (
        .key_in (keyx_in),
        .round  (keyx_round_idx),
        .key_out(next_key)
    );

    wire [127:0] round_key_used = next_key;

    // ---- Round combinational block ----------------------------------------
    wire [127:0] round_state_out;
    encrypt_round u_round (
        .last_round(last_round),
        .state_in  (round_in_state),
        .round_key (round_key_used),
        .state_out (round_state_out)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            round_cnt  <= 4'h0;
            state_reg  <= 128'b0;
            key_reg    <= 128'b0;
            ciphertext <= 128'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            if (idle) begin
                if (start) begin
                    state_reg <= round_state_out;   
                    key_reg   <= next_key;          
                    round_cnt <= 4'd2;
                end
            end else if (last_round) begin
                ciphertext <= round_state_out;      
                done       <= 1'b1;
                round_cnt  <= 4'h0; //quay ve idle
            end else begin
                state_reg <= round_state_out;
                key_reg   <= next_key;              
                round_cnt <= round_cnt + 4'd1;
            end
        end
    end

endmodule 
