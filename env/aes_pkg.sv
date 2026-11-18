package aes_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //---- Mo hinh tham chieu ----
  import "DPI-C" function void aes128_enc_ref(input   bit [127:0] key,
                                              input   bit [127:0] pt,
                                              output  bit [127:0] ct);
  import "DPI-C" function void aes128_dec_ref(input   bit [127:0] key,
                                              input   bit [127:0] ct,
                                              output  bit [127:0] pt);
                                            
  // ---- phan loai du lieu, coverage dung ----
  typedef enum { PAT_ZERO, PAT_ONES, PAT_OTHER } pat_e;

  function automatic pat_e classify(bit [127:0] v);
    if (v == '0)      return PAT_ZERO;
    else if (v == '1) return PAT_ONES;
    else              return PAT_OTHER;
  endfunction

  `include "aes_item.sv"
  `include "aes_item_tight.sv"
  `include "aes_config.sv"
  `include "aes_driver.sv"
  `include "aes_monitor.sv"
  `include "aes_sequencer.sv"
  `include "aes_agent.sv"
  `include "aes_scoreboard.sv"   
  `include "aes_coverage.sv"    
  `include "aes_env.sv"
  `include "aes_seq_lib.sv"
  `include "aes_test_lib.sv"
endpackage 