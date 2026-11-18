class aes_config extends uvm_object;
  uvm_active_passive_enum is_active     = UVM_ACTIVE;
  
  int unsigned lat_enc = 10;
  int unsigned lat_dec = 21;

  bit drop_inputs_after_start = 1;
  bit enable_sbox_cov = 1;

  `uvm_object_utils_begin(aes_config)
    `uvm_field_int(lat_enc,                  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(lat_dec,                  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(drop_inputs_after_start,  UVM_ALL_ON)
    `uvm_field_int(enable_sbox_cov,          UVM_ALL_ON)
  `uvm_object_utils_end 

  function new(string name = "aes_config");
    super.new(name);
  endfunction

  function int unsigned exp_lat(bit mode);
    return mode ? lat_dec : lat_enc;
  endfunction 
endclass 