module aes_sva (
    input logic         clk,
    input logic         rst_n,
    input logic         start,
    input logic         mode,
    input logic [127:0] data_in,
    input logic [127:0] key,
    input logic [127:0] data_out,
    input logic         done,
    input logic         busy
);

  import uvm_pkg::*;

  default clocking cb @(posedge clk); endclocking

  // Cạnh nhận, định nghĩa y như spec, driver và monitor dùng.
  wire accept     = start && !busy;
  wire accept_enc = accept && !mode;
  wire accept_dec = accept &&  mode;

  // ---- REQ-TIME-01 / REQ-TIME-02 : latency chính xác ----
  property p_lat_enc;
    disable iff (!rst_n) accept_enc |-> ##10 done;
  endproperty

  property p_lat_dec;
    disable iff (!rst_n) accept_dec |-> ##21 done;
  endproperty

  // done cũng không được đến sớm
  property p_no_early_enc;
    disable iff (!rst_n) accept_enc |=> !done [*9];
  endproperty

  property p_no_early_dec;
    disable iff (!rst_n) accept_dec |=> !done [*20];
  endproperty

  // ---- REQ-TIME-04 : done rộng đúng 1 chu kỳ ----
  property p_done_pulse;
    disable iff (!rst_n) done |=> !done;
  endproperty

  // ---- REQ-HS-04 : busy và done loại trừ nhau ----
  property p_busy_done_excl;
    disable iff (!rst_n) !(busy && done);
  endproperty

  // ---- REQ-HS-03 : busy lên sau khi nhận, và chỉ khi đó ----
  property p_busy_after_accept;
    disable iff (!rst_n) accept |=> busy;
  endproperty

  property p_busy_rise_cause;
    disable iff (!rst_n) $rose(busy) |-> $past(accept);
  endproperty

  // ---- REQ-OUT-01 : data_out bằng 0 khi không có done ----
  property p_out_gated;
    disable iff (!rst_n) !done |-> (data_out == 128'd0);
  endproperty

  // ---- không được có X ở những gì DUT hành động theo ----
  property p_no_x_ctrl;
    disable iff (!rst_n) !$isunknown({start, busy, done});
  endproperty

  property p_no_x_req;
    disable iff (!rst_n) accept |-> !$isunknown({mode, data_in, key});
  endproperty

  a_lat_enc: assert property (p_lat_enc)
    else uvm_report_error("SVA", "encrypt done did not land exactly 10 cycles after the accept");

  a_lat_dec: assert property (p_lat_dec)
    else uvm_report_error("SVA", "decrypt done did not land exactly 21 cycles after the accept");

  a_no_early_enc: assert property (p_no_early_enc)
    else uvm_report_error("SVA", "encrypt done came earlier than 10 cycles");

  a_no_early_dec: assert property (p_no_early_dec)
    else uvm_report_error("SVA", "decrypt done came earlier than 21 cycles");

  a_done_pulse: assert property (p_done_pulse)
    else uvm_report_error("SVA", "done stayed high for more than one cycle");

  a_busy_done_excl: assert property (p_busy_done_excl)
    else uvm_report_error("SVA", "busy and done were high in the same cycle");

  a_busy_after_accept: assert property (p_busy_after_accept)
    else uvm_report_error("SVA", "busy did not rise in the cycle after an accept");

  a_busy_rise_cause: assert property (p_busy_rise_cause)
    else uvm_report_error("SVA", "busy rose without an accept in the cycle before");

  a_out_gated: assert property (p_out_gated)
    else uvm_report_error("SVA", "data_out was non-zero while done was low");

  a_no_x_ctrl: assert property (p_no_x_ctrl)
    else uvm_report_error("SVA", "X seen on start, busy or done");

  a_no_x_req: assert property (p_no_x_req)
    else uvm_report_error("SVA", "a request was accepted with X on mode, data_in or key");

  // ---- cover: các góc mình muốn chứng minh là thật sự đã chạy qua ----
  // Nhóm này không có disable iff, để cái cover về reset bắt được.
  c_tight_b2b:     cover property (@(posedge clk) rst_n && done && accept);
  c_start_ignored: cover property (@(posedge clk) rst_n && start && busy);
  c_enc_then_dec:  cover property (@(posedge clk) rst_n && accept_enc ##[1:40] accept_dec);
  c_dec_then_enc:  cover property (@(posedge clk) rst_n && accept_dec ##[1:40] accept_enc);
  c_reset_mid_op:  cover property (@(posedge clk) busy ##1 !rst_n);
  c_zero_data:     cover property (@(posedge clk) rst_n && accept && data_in == 128'd0);
  c_zero_key:      cover property (@(posedge clk) rst_n && accept && key     == 128'd0);

endmodule

// Bind vào mọi thể hiện của wrapper, nên tb_top không phải sửa gì và
// assertion đi theo DUT dù nó được instantiate ở đâu.
bind aes_dut_wrap aes_sva u_sva (.*);