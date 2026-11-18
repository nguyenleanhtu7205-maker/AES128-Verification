covergroup cg_sbox_byte with function sample(bit [7:0] b);
  option.per_instance = 1;
  coverpoint b {
    bins val[256] = {[0:255]};
  }
endgroup

class aes_coverage extends uvm_subscriber #(aes_item);

  `uvm_component_utils(aes_coverage)

  aes_config cfg;

  bit          cp_mode;
  int unsigned cp_lat;
  int          cp_gap;
  pat_e        cp_din_pat;
  pat_e        cp_key_pat;

  covergroup cg_txn;
    option.per_instance = 1;

    dir: coverpoint cp_mode {
      bins enc = {0};
      bins dec = {1};
    }

    lat: coverpoint cp_lat {
      bins enc_10 = {10};
      bins dec_21 = {21};
      bins other  = default;        
    }


    gap: coverpoint cp_gap {
      bins first = {-1};
      bins tight = {0};               
      bins short = {[1:3]};
      bins mid   = {[4:8]};
      bins long  = {[9:32]};
    }

    din: coverpoint cp_din_pat {
      bins zero  = {PAT_ZERO};
      bins ones  = {PAT_ONES};
      bins other = {PAT_OTHER};
    }

    keyp: coverpoint cp_key_pat {
      bins zero  = {PAT_ZERO};
      bins ones  = {PAT_ONES};
      bins other = {PAT_OTHER};
    }

    trans: coverpoint cp_mode {
      bins e2e = (0 => 0);
      bins e2d = (0 => 1);
      bins d2e = (1 => 0);
      bins d2d = (1 => 1);
    }

    dir_x_din : cross dir, din;

    dir_x_gap : cross dir, gap {
      ignore_bins no_first = binsof(gap.first);
    }
  endgroup

  cg_sbox_byte sbox_cg[16];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_txn = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(aes_config)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "no aes_config in config_db")
    if (cfg.enable_sbox_cov)
      foreach (sbox_cg[i])
        sbox_cg[i] = new();
  endfunction

  function void write(aes_item t);
    cp_mode    = t.mode;
    cp_lat     = t.latency;
    cp_gap     = t.gap_cycles;
    cp_din_pat = classify(t.data_in);
    cp_key_pat = classify(t.key);
    cg_txn.sample();

    if (cfg.enable_sbox_cov && t.mode == 1'b0) begin
      bit [127:0] first_round_in = t.data_in ^ t.key;
      foreach (sbox_cg[i])
        sbox_cg[i].sample(first_round_in[127 - 8*i -: 8]);
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("cg_txn = %0.2f %%", cg_txn.get_inst_coverage()),
              UVM_LOW)
  endfunction

endclass