`timescale 1ns/1ps
//======================================================================
// tb_bringup.sv -- Stage 0 bring-up cho AES-128 top
// Verilog thuan, khong UVM, khong DPI.
//======================================================================

module tb_bringup;

  reg clk = 1'b0;
  always #5 clk = ~clk;                 // 100 MHz

  reg          rst_n, start, mode;
  reg  [127:0] data_in, key;
  wire [127:0] data_out;
  wire         done, busy;

  aes_dut_wrap dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (start),
    .mode     (mode),                   
    .data_in  (data_in),
    .key      (key),
    .data_out (data_out),
    .done     (done),
    .busy     (busy)
  );

  // ---- vector FIPS-197 -----------------------------------------------
  localparam [127:0] KEY_A = 128'h000102030405060708090a0b0c0d0e0f;
  localparam [127:0] PT_A  = 128'h00112233445566778899aabbccddeeff;
  localparam [127:0] CT_A  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

  localparam [127:0] KEY_B = 128'h2b7e151628aed2a6abf7158809cf4f3c;
  localparam [127:0] PT_B  = 128'h3243f6a8885a308d313198a2e0370734;
  localparam [127:0] CT_B  = 128'h3925841d02dc09fbdc118597196a0b32;

  integer fail = 0, pass = 0;

  // ---- reset dong bo: phai giu thap qua cac canh len that -------------
  task do_reset;
    begin
      rst_n   = 0;
      start   = 0;
      mode    = 0;
      data_in = 0;
      key     = 0;
      repeat (3) @(posedge clk);
      #1 rst_n = 1;
      @(posedge clk);
    end
  endtask

  // ---- mot phep tinh, dem latency theo gia tri lay mau ---------------
  task do_op (input           md,
              input   [127:0] din,
              input   [127:0] k,
              output  [127:0] dout,
              output  integer lats);
    integer i;
    begin
      #1 start = 0;
      while (busy || done) @(posedge clk);   
      @(posedge clk);
      #1;
      mode    = md;
      data_in = din;
      key     = k;
      start   = 1;
      @(posedge clk);                       
      #1;
      start   = 0;
      data_in = 128'hx;                      
      key     = 128'hx;
      mode    = 1'bx;
      lats    = 0;
      dout    = 128'hx;
      for (i = 1; i <= 60; i = i + 1) begin
        @(posedge clk);
        if (done && lats == 0) begin
          lats = i;
          dout = data_out;
        end
      end
      #1;
      mode    = 0;
      data_in = 0;
      key     = 0;
      if (lats == 0) begin
        fail = fail + 1;
        $display("[FAIL] khong co done trong 60 chu ky");
      end
    end
  endtask

  task check_result(
    input [8*48:1] name,
    input [127:0]  got_dout,
    input [127:0]  exp_dout,
    input integer  got_lats,
    input integer  exp_lats
  );
  begin
    if ((got_dout !== exp_dout) || (got_lats !== exp_lats)) begin
      fail = fail + 1;
      $display("[FAIL] %0s | data = %h (exp = %h) | lat = %0d (exp = %0d)",
                name, got_dout, exp_dout, got_lats, exp_lats);
      if (got_dout !== exp_dout)
        $display("       xor = %h", got_dout ^ exp_dout);
    end else begin
      pass = pass + 1;
      $display("[PASS] %0s | data = %h | lat = %0d", name, got_dout, got_lats);
    end
  end
  endtask

  task check_int(input [8*48:1] name, input integer got, input integer exp);
  begin
    if (got !== exp) begin
      fail = fail + 1;
      $display("[FAIL] %0s = %0d (exp = %0d)", name, got, exp);
    end else begin
      pass = pass + 1;
      $display("[PASS] %0s = %0d", name, got);
    end
  end
  endtask

  // ---- hai watcher chay lien tuc -------------------------------------
  integer n_gate_err = 0;
  integer n_excl_err = 0;

  always @(posedge clk) begin
    if (rst_n === 1'b1) begin
      if (!done && (data_out !== 128'b0)) begin
        n_gate_err = n_gate_err + 1;
        if (n_gate_err <= 3)
          $display("[FAIL] PROTOCOL %0t: done=0 nhung data_out = %h",
                   $time, data_out);
      end
      if (busy && done) begin
        n_excl_err = n_excl_err + 1;
        if (n_excl_err <= 3)
          $display("[FAIL] PROTOCOL %0t: busy va done cung cao", $time);
      end
    end
  end

  reg [127:0] res_data, rt_data;
  integer     res_lats;
  integer     i, nd;

  initial begin
    $display("==== BAT DAU BRINGUP TESTBENCH AES128 ====");
    do_reset();

    // 1. sau reset
    if (busy !== 1'b0 || done !== 1'b0 || data_out !== 128'b0) begin
      fail = fail + 1;
      $display("[FAIL] Reset: busy = %b done = %b data_out = %h",
               busy, done, data_out);
    end else begin
      pass = pass + 1;
      $display("[PASS] Reset OK");
    end

    // 2. ma hoa va giai ma, hai vector FIPS
    do_op(1'b0, PT_A, KEY_A, res_data, res_lats);
    check_result("EN_A", res_data, CT_A, res_lats, 10);

    do_op(1'b1, CT_A, KEY_A, res_data, res_lats);
    check_result("DE_A", res_data, PT_A, res_lats, 21);

    do_op(1'b0, PT_B, KEY_B, res_data, res_lats);
    check_result("EN_B", res_data, CT_B, res_lats, 10);

    do_op(1'b1, CT_B, KEY_B, res_data, res_lats);
    check_result("DE_B", res_data, PT_B, res_lats, 21);

    // 3. round trip: ma hoa roi giai ma lai phai ve ban goc
    do_op(1'b0, PT_B, KEY_A, rt_data,  res_lats);
    do_op(1'b1, rt_data, KEY_A, res_data, res_lats);
    check_result("RTRIP", res_data, PT_B, res_lats, 21);

    // 4. day start trong luc busy: DUT phai bo qua hoan toan
    //    Khong co kiem tra nay thi mot DUT mat chan busy van xanh het.
    #1; mode = 1'b0; data_in = PT_A; key = KEY_A; start = 1'b1;
    @(posedge clk); #1 start = 1'b0;              // canh 0
    repeat (3) @(posedge clk);
    #1; mode = 1'b1; data_in = 128'hdead_beef_dead_beef_dead_beef_dead_beef;
        key = 128'b0; start = 1'b1;               // poke, phai bi bo qua
    repeat (2) @(posedge clk);
    #1; start = 1'b0; mode = 1'b0; data_in = 0; key = 0;
    nd = 0; res_lats = 0;
    for (i = 6; i <= 60; i = i + 1) begin
      @(posedge clk);
      if (done) begin
        nd = nd + 1;
        if (res_lats == 0) begin
          res_lats = i;
          res_data = data_out;
        end
      end
    end
    check_int("so xung done sau poke", nd, 1);
    check_result("POKE", res_data, CT_A, res_lats, 10);

    // 5. reset giua phep tinh: giao dich bi huy am tham, khong co done
    #1; mode = 1'b0; data_in = PT_A; key = KEY_A; start = 1'b1;
    @(posedge clk); #1 start = 1'b0;
    repeat (4) @(posedge clk);
    #1 rst_n = 1'b0;
    nd = 0;
    for (i = 0; i < 12; i = i + 1) begin
      @(posedge clk);
      if (done) nd = nd + 1;
    end
    #1 rst_n = 1'b1;
    check_int("so xung done sau reset giua phep tinh", nd, 0);
    @(posedge clk); #1;
    check_int("busy sau reset", busy ? 1 : 0, 0);

    do_op(1'b0, PT_A, KEY_A, res_data, res_lats);
    check_result("AFTRST", res_data, CT_A, res_lats, 10);

    // 6. ket qua cua hai watcher
    check_int("chu ky data_out khac 0 khi done=0", n_gate_err, 0);
    check_int("chu ky busy va done cung cao",      n_excl_err, 0);

    $display("==== TONG KET ====");
    $display("pass = %0d, fail = %0d", pass, fail);
    if (fail == 0)
      $display(">>> BRING UP TESTBENCH PASS <<<");
    else
      $display(">>> BRING UP TESTBENCH FAIL <<<");
    $display("==================");

    $finish;
  end

  // chot chan cuoi, neu testbench treo
  initial begin
    #500000;
    $display(">>> BRING UP TESTBENCH FAIL (timeout) <<<");
    $finish;
  end

endmodule
