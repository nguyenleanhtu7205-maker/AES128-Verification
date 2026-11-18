class aes_base_test extends uvm_test;

  `uvm_component_utils(aes_base_test)

  aes_env        env;
  aes_config     cfg;
  virtual aes_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = aes_config::type_id::create("cfg");
    configure(cfg);
    uvm_config_db #(aes_config)::set(this, "*", "cfg", cfg);
    if (!uvm_config_db #(virtual aes_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "no virtual interface in config_db")
    env = aes_env::type_id::create("env", this);
  endfunction

  virtual function void configure(aes_config c);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_stimulus();
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "stimulus running");
    vif.do_reset(5);
    run_stimulus();
    repeat (cfg.lat_dec + 5) @(vif.mon_cb);
    phase.drop_objection(this, "stimulus done");
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) == 0 &&
        svr.get_severity_count(UVM_FATAL) == 0)
      $display("\n*** TEST PASSED ***\n");
    else
      $display("\n*** TEST FAILED ***\n");
  endfunction

endclass

// ---- B2B ----
class aes_b2b_test extends aes_base_test;
  `uvm_component_utils(aes_b2b_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    set_type_override_by_type(aes_item::get_type(), aes_item_tight::get_type());
    super.build_phase(phase);
  endfunction

  task run_stimulus();
    aes_random_seq seq = aes_random_seq::type_id::create("seq");
    seq.n_items = 100;
    seq.start(env.agt.sqr);
  endtask
endclass

// ---- reset ----
class aes_reset_test extends aes_base_test;
  `uvm_component_utils(aes_reset_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_random_seq s1 = aes_random_seq::type_id::create("s1");
    aes_random_seq s2 = aes_random_seq::type_id::create("s2");
    aes_kat_seq    s3 = aes_kat_seq   ::type_id::create("s3");

    s1.n_items = 20;
    s2.n_items = 40;

    s1.start(env.agt.sqr);                 

    fork
      begin                               
        repeat (60) @(vif.mon_cb);
        `uvm_info(get_type_name(), "asserting reset during traffic", UVM_LOW)
        vif.do_reset(4);
      end
    join_none
    s2.start(env.agt.sqr);

    repeat (cfg.lat_dec + 5) @(vif.mon_cb);
    s3.start(env.agt.sqr);                
  endtask
endclass

// ---- KAT ----
class aes_kat_test extends aes_base_test;
  `uvm_component_utils(aes_kat_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void configure(aes_config c);
    c.enable_sbox_cov = 0;          
  endfunction

  task run_stimulus();
    aes_kat_seq seq = aes_kat_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass

//---- random ---- 
class aes_random_test extends aes_base_test;
  `uvm_component_utils(aes_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_random_seq seq = aes_random_seq::type_id::create("seq");
    if (!seq.randomize() with { seq.n_items inside {[80:160]}; })
      `uvm_error(get_type_name(), "randomize failed")
    seq.start(env.agt.sqr);
  endtask
endclass

//---- patterns ----
class aes_pattern_test extends aes_base_test;
  `uvm_component_utils(aes_pattern_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_pattern_seq seq = aes_pattern_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass

//---- same key ----
class aes_same_key_test extends aes_base_test;
  `uvm_component_utils(aes_same_key_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_same_key_seq seq = aes_same_key_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass

// ---- mode toggle ----
class aes_mode_toggle_test extends aes_base_test;
  `uvm_component_utils(aes_mode_toggle_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_mode_toggle_seq seq = aes_mode_toggle_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass

//---- round trip ----
class aes_roundtrip_test extends aes_base_test;
  `uvm_component_utils(aes_roundtrip_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_roundtrip_seq seq = aes_roundtrip_seq::type_id::create("seq");
    seq.start(env.agt.sqr);
  endtask
endclass

// ---- All of the above ----
class aes_all_test extends aes_base_test;
  `uvm_component_utils(aes_all_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  task run_stimulus();
    aes_kat_seq         k = aes_kat_seq        ::type_id::create("k");
    aes_pattern_seq     p = aes_pattern_seq    ::type_id::create("p");
    aes_same_key_seq    s = aes_same_key_seq   ::type_id::create("s");
    aes_mode_toggle_seq m = aes_mode_toggle_seq::type_id::create("m");
    aes_roundtrip_seq   r = aes_roundtrip_seq  ::type_id::create("r");
    aes_random_seq      n = aes_random_seq     ::type_id::create("n");

    k.start(env.agt.sqr);
    p.start(env.agt.sqr);
    s.start(env.agt.sqr);
    m.start(env.agt.sqr);
    r.start(env.agt.sqr);
    n.n_items = 150;
    n.start(env.agt.sqr);
  endtask
endclass