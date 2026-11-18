class aes_driver extends uvm_driver #(aes_item);
  `uvm_component_utils(aes_driver)

  virtual aes_if vif;
  aes_config     cfg;

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction 

  function void build_phase (uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(virtual aes_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Driver khong lay duoc virtual interface")
    if(!uvm_config_db #(aes_config) ::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "Driver khong lay duoc aes_config")
  endfunction 

  task run_phase(uvm_phase phase);
    aes_item tr;
    idle_pins();
    wait (vif.rst_n === 1'b1);
    @(vif.drv_cb);
    forever begin
      seq_item_port.get_next_item(tr);
      drive_item(tr);
      seq_item_port.item_done();
    end 
  endtask 

  task idle_pins();
    vif.drv_cb.start    <= 1'b0;
    vif.drv_cb.mode     <= 1'b0;
    vif.drv_cb.data_in  <= 128'b0;
    vif.drv_cb.key      <= 128'b0;
  endtask 

  task drive_item (aes_item tr);
    wait (vif.rst_n === 1'b1);
    if(tr.gap > 0) begin
      //Cho phep tinh dang chay xong, roi cho gap chu ky
      while (vif.drv_cb.busy === 1'b1) @(vif.drv_cb);
      repeat (tr.gap) @(vif.drv_cb);
    end 

    vif.drv_cb.start      <= 1'b1;
    vif.drv_cb.mode       <= tr.mode;
    vif.drv_cb.data_in    <= tr.data_in;
    vif.drv_cb.key        <= tr.key;

    forever begin
      @(vif.drv_cb);
      if(vif.drv_cb.rst_n === 1'b1 && vif.drv_cb.busy !== 1'b1) break;
    end 

    vif.drv_cb.start <= 1'b0;
    if(cfg.drop_inputs_after_start) begin
      vif.drv_cb.data_in <= 'x;
      vif.drv_cb.key     <= 'x;
      vif.drv_cb.mode    <= 1'bx;
    end 

    `uvm_info(get_type_name(), 
              $sformatf("accecpt %s key = %032h in=%032h",
              tr.dir_str(), tr.key, tr.data_in), UVM_HIGH)
  endtask 

endclass 