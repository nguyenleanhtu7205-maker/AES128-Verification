`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 11:01:41 PM
// Design Name: 
// Module Name: aes128_decrypt
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


module aes128_decrypt (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] ciphertext,
    input  wire [127:0] key,           
    output reg  [127:0] plaintext,
    output reg          done,
    output wire         busy
);

    // ---- FSM state ---------------------------------------------------------
    localparam S_IDLE    = 2'd0;
    localparam S_KEYEXP  = 2'd1;    //Phase A: tinh den round key cuoi cung (tu k0 -> k10)    
    localparam S_DEC     = 2'd2;    //Phase B: giai ma + lui key (k10->k0)

    reg [1:0] state;
    reg [3:0] cnt;                       

    // ---- Datapath registers ------------------------------------------------
    reg [127:0] state_reg;  //state trung gian giua cac round         
    reg [127:0] key_reg;    //round  key hien tai               

    // ---- Forward key expander (Phase A) -----------------------------------
    wire [127:0] fwd_next_key;
    key_expansion u_fkeyx (
        .key_in (key_reg),
        .round  (cnt),                   
        .key_out(fwd_next_key)
    );

    // ---- Inverse key expander (Phase B) -----------------------------------
    wire [127:0] inv_next_key;
    inv_key_expansion u_ikeyx (
        .key_in (key_reg),               
        .round  (4'd11 - cnt),            
        .key_out(inv_next_key)
    );

    wire is_last_inv = (cnt == 4'd10);
    //(state_reg ^ key_reg) <=> (ciphertext ^ key_reg) : do state_reg ranh nen muon de chot ciphertext
    wire [127:0] inv_round_state_in = (state == S_DEC && cnt == 4'd1)
                                       ? (state_reg ^ key_reg)
                                       : state_reg;
    wire [127:0] inv_round_key      = inv_next_key;

    wire [127:0] inv_round_out;
    decrypt_round u_inv_round (
        .last_round(is_last_inv),
        .state_in  (inv_round_state_in),
        .round_key (inv_round_key),
        .state_out (inv_round_out)
    );

    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cnt       <= 4'd0;
            state_reg <= 128'b0;
            key_reg   <= 128'b0;
            plaintext <= 128'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        key_reg   <= key;
                        state_reg <= ciphertext;  //state_reg dang ranh o nhung chu  ky dau, tan dung chot gia tri ciphertext 
                        cnt       <= 4'd1;        //Bat dau sinh round key 1 
                        state     <= S_KEYEXP;
                    end
                end

                S_KEYEXP: begin
                    key_reg <= fwd_next_key;
                    if (cnt == 4'd10) begin
                        cnt   <= 4'd1;
                        state <= S_DEC;
                    end else begin
                        cnt <= cnt + 4'd1;
                    end
                end

                S_DEC: begin
                    state_reg <= inv_round_out;
                    key_reg   <= inv_next_key;
                    if (cnt == 4'd10) begin
                        plaintext <= inv_round_out;
                        done      <= 1'b1;
                        state     <= S_IDLE;
                        cnt       <= 4'd0;
                    end else begin
                        cnt <= cnt + 4'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule 