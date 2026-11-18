class aes_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(aes_scoreboard)

  uvm_analysis_imp #(aes_item, aes_scoreboard) item_imp;
  aes_config cfg;

  int unsigned n_checked;
  int unsigned n_enc;
  int unsigned n_dec;
  int unsigned n_data_err;
  int unsigned n_lat_err;

  function new (string name, uvm_component parent);
    super.new(name, parent);
    item_imp = new("item_imp", this);
  endfunction 

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(aes_config)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "Scoreboard khong lay duoc config")
  endfunction 

  function void write (aes_item tr);
    bit [127:0] exp;
    int unsigned exp_lat;

    if(tr.mode) begin
      aes128_dec_ref(tr.key, tr.data_in, exp);
      n_dec ++;
    end else begin
      aes128_enc_ref(tr.key, tr.data_in, exp);
      n_enc ++;
    end 

    exp_lat = cfg.exp_lat(tr.mode);

    if(tr.data_out !== exp) begin
      n_data_err ++;
      `uvm_error(get_type_name(), 
                  $sformatf({"%s result mismatch\n",
                             "    key = %032h\n",
                             "    in  = %032h\n",
                             "    got = %032h\n",
                             "    exp = %032h"},
                              tr.dir_str(), tr.key, tr.data_in,
                              tr.data_out, exp))
    end 

    if(tr.latency !== exp_lat) begin
      n_lat_err ++;
      `uvm_error(get_type_name(), $sformatf("%s latency %0d, expected %0d (key=%032h in=%032h)",
                           tr.dir_str(), tr.latency, exp_lat,
                           tr.key, tr.data_in))
    end 

    if(tr.data_out === exp && tr.latency === exp_lat) begin
      n_checked ++;
    end 
  endfunction 

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), 
              $sformatf("checked=%0d (enc=%0d dec=%0d) data_err=%0d lat_err=%0d",
                        n_checked, n_enc, n_dec, n_data_err, n_lat_err),
              UVM_LOW)
    if (n_checked == 0)
      `uvm_error(get_type_name(), "scoreboard khong thay transaction")
  endfunction 

endclass 