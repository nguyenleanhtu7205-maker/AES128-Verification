class aes_item extends uvm_sequence_item;
  // --- Yeu cau ---
  rand bit          mode;
  rand bit [127:0]  data_in;
  rand bit [127:0]  key;
  rand int unsigned gap;

  // --- quan sat duoc ---
  bit [127:0]  data_out;
  int unsigned latency;
  int          gap_cycles;

  constraint c_gap {gap dist {0 := 2, [1:3] := 5, [4:10] := 3};}

  `uvm_object_utils_begin(aes_item)
    `uvm_field_int(mode,        UVM_ALL_ON)
    `uvm_field_int(data_in,     UVM_ALL_ON)
    `uvm_field_int(key,         UVM_ALL_ON)
    `uvm_field_int(gap,         UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(data_out,    UVM_ALL_ON)
    `uvm_field_int(latency,     UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(gap_cycles,  UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end 

  function new (string name = "aes_item");
    super.new(name);
  endfunction 

  function string dir_str();
    return mode ? "DEC" : "ENC";
  endfunction 

  function string convert2string();
    return $sformatf("%s key = %032h | in = %032h | out = %032h | lat = %0d | gap = %0d",
                      dir_str(), key, data_in, data_out, latency, gap_cycles);
  endfunction 
endclass 