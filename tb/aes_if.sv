interface aes_if (input clk);
  logic         rst_n;
  logic         start;
  logic         mode;
  logic [127:0] data_in;
  logic [127:0] key;
  logic [127:0] data_out;
  logic         done;
  logic         busy;

  //Driver
  clocking drv_cb @(posedge clk);
    default input#1step output #1;
    output start, mode, data_in, key;
    input  rst_n, busy, done, data_out;
  endclocking 

  //Monitor
  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, start, mode, data_in, key, data_out, done, busy;
  endclocking 

  modport DRV (clocking drv_cb);
  modport MON (clocking mon_cb);

  task automatic do_reset (int unsigned cycles = 5);
    rst_n <= 1'b0;
    repeat (cycles) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
  endtask 
endinterface 