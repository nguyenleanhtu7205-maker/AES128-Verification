class aes_env extends uvm_env;
  `uvm_component_utils(aes_env)

  aes_agent   agt;
  aes_config  cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction 

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(aes_config)::get(this, "", "cfg", cfg))
      `uvm_error(get_type_name(), "Env khong lay duoc config")
    agt = aes_agent::type_id::create("agt", this);
  endfunction 

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  
  endfunction 
endclass 