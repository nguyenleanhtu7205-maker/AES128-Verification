class aes_monitor extends uvm_monitor;
  `uvm_component_utils(aes_monitor)

  virtual aes_if                vif;
  aes_config                    cfg;
  uvm_analysis_port #(aes_item) ap;

  int unsigned n_accepted;
  int unsigned n_done;
  int unsigned n_ignored_start; //start cao khi busy
  int unsigned n_idle;
  int unsigned n_dropped;       //dang bay thi gap reset

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction 

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(virtual aes_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Monitor khong lay duoc interface")
    if(!uvm_config_db #(aes_config)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "Monitor khong lay duoc config")
  endfunction 

  task run_phase(uvm_phase phase);
    aes_item pend;
    int      cycle;
    int      accept_cycle;
    int      last_done_cycle;

    pend            = null;
    cycle           = 0;
    accept_cycle    = 0;
    last_done_cycle = -1;

    forever begin
      @(vif.mon_cb);
      cycle ++;

      //--- Reset ---
      if(vif.mon_cb.rst_n !== 1'b1) begin
        if(pend != null) begin
          n_dropped ++;
          `uvm_info(get_type_name(), "Reset during an operation", UVM_MEDIUM)
          pend = null;
        end 
        last_done_cycle = -1;
        continue;
      end 

      //---- done ----
      if(vif.mon_cb.done === 1'b1) begin
        n_done ++;
        if(pend == null) begin
          `uvm_error(get_type_name(), "pend = null khi done = 1")
        end 
        else begin
          pend.data_out = vif.mon_cb.data_out;
          pend.latency  = cycle - accept_cycle;
          ap.write(pend);
          `uvm_info(get_type_name(), pend.convert2string(), UVM_HIGH)
          pend = null;
        end 
        last_done_cycle = cycle;
      end 

      //---- start ----
      if(vif.mon_cb.start === 1'b1 && vif.mon_cb.busy !== 1'b1) begin
        if(pend != null)
          `uvm_error(get_type_name(), "Pend != null khi start = 1 va busy = 0")
        n_accepted ++;
        pend            = aes_item::type_id::create("mon_tr");
        pend.mode       = vif.mon_cb.mode;
        pend.data_in    = vif.mon_cb.data_in;
        pend.key        = vif.mon_cb.key;
        pend.gap_cycles = (last_done_cycle < 0) ? -1 : (cycle - last_done_cycle);
        accept_cycle    = cycle;

        if(vif.mon_cb.mode === 1'bx || $isunknown(vif.mon_cb.data_in) || $isunknown(vif.mon_cb.key)) 
          `uvm_error(get_type_name(), "Loi mode, data_in hoac key")
        end 
        else if(vif.mon_cb.start === 1'b1 && vif.mon_cb.busy === 1'b1) begin
          n_ignored_start ++;
        end else if (vif.mon_cb.busy !== 1'b1 && vif.mon_cb.done !== 1'b1) begin
          n_idle ++;
        end 
      end 
  endtask 

      function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), 
                  $sformatf("accepted = %0d | done = %0d | ignored_start = %0d | idle = %0d | dropped = %0d",
                  n_accepted, n_done, n_ignored_start, n_idle, n_dropped),
                  UVM_LOW)
        if(n_accepted != (n_done + n_dropped))
          `uvm_error(get_type_name(), 
                     $sformatf("Mismatch (accept != done + drop): accepted = %0d | done = %0d | drop = %0d",
                     n_accepted, n_done, n_dropped))
      endfunction 
endclass 