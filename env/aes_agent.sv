class aes_agent extends uvm_agent;
  `uvm_component_utils(aes_agent)
  
  aes_sequencer sqr;
  aes_driver    drv;
  aes_monitor   mon;
  aes_config    cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction 

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(aes_config)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "agent khong lay duoc config")
    
    mon = aes_monitor::type_id::create("mon", this);
    
    is_active = cfg.is_active;

    if (is_active == UVM_ACTIVE) begin
      sqr = aes_sequencer::type_id::create("sqr", this);
      drv = aes_driver::type_id::create("drv", this);
    end 
  endfunction 

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass 