module aes_dut_wrap (
  input wire          clk,
  input wire          rst_n,
  input wire          start,
  input wire          mode, 
  input wire [127:0]  data_in,
  input wire [127:0]  key,
  output wire [127:0] data_out,
  output wire         done,
  output wire         busy
);
  wire [127:0] dut_data_out;
  wire         dut_done;

  aes128_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .mode(mode),
    .data_in(data_in),
    .key(key),
    .data_out(dut_data_out),
    .done(dut_done),
    .busy(busy)
  );

  `ifdef WRAP_BUG_DONE_WIDE
    reg done_d;
    always @(posedge clk) 
      if(!rst_n) done_d <= 1'b0;
      else done_d <= dut_done;
    assign done = dut_done | done_d;
  `else
    assign done = dut_done;
  `endif 

  `ifdef WRAP_BUG_LATA_DATA
    reg [127:0] data_d;
    always @(posedge clk) 
      if(!rst_n) data_d <= 128'b0;
      else data_d <= dut_data_out;
    assign data_out = data_d;
  `elsif WRAP_BUG_NO_GATE
    reg [127:0] data_hold;
    always @(posedge clk)
      if(!rst_n) data_hold <= 128'b0;
      else if (dut_done) data_hold <= dut_data_out;
    assign data_out = dut_done ? dut_data_out : data_hold;
  `else
    assign data_out = dut_data_out;
  `endif 

  
endmodule 