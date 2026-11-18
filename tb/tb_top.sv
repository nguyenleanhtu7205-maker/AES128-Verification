`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  import aes_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  always #5 clk = ~clk;                  

  aes_if vif (.clk(clk));

  aes_dut_wrap dut (
      .clk      (clk),
      .rst_n    (vif.rst_n),
      .start    (vif.start),
      .mode     (vif.mode),
      .data_in  (vif.data_in),
      .key      (vif.key),
      .data_out (vif.data_out),
      .done     (vif.done),
      .busy     (vif.busy)
  );

  initial begin
    vif.rst_n   = 1'b0;                  
    vif.start   = 1'b0;
    vif.mode    = 1'b0;
    vif.data_in = '0;
    vif.key     = '0;
  end

  initial begin
    uvm_config_db #(virtual aes_if)::set(null, "*", "vif", vif);
    if ($test$plusargs("WAVE")) begin
      $shm_open("waves.shm");
      $shm_probe("ACMTF");
    end
    run_test();
  end

  initial begin
    #2ms;
    `uvm_fatal("TB_TOP", "global timeout: 2 ms of simulated time elapsed")
  end

endmodule