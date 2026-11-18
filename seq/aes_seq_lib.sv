class aes_base_seq extends uvm_sequence #(aes_item);

  `uvm_object_utils(aes_base_seq)

  rand int unsigned n_items;
  constraint c_n { n_items inside {[1:400]}; }

  function new(string name = "aes_base_seq");
    super.new(name);
    n_items = 20;
  endfunction

  task send(bit mode_i, bit [127:0] din_i, bit [127:0] key_i,
            int unsigned gap_i = 2);
    aes_item tr;
    tr = aes_item::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with { mode    == mode_i;
                               data_in == din_i;
                               key     == key_i;
                               gap     == gap_i; })
      `uvm_error(get_type_name(), "randomize cua send() tha bai")
    finish_item(tr);
  endtask

endclass

// ----- random -----
class aes_random_seq extends aes_base_seq;
  `uvm_object_utils(aes_random_seq)
  function new(string name = "aes_random_seq");
    super.new(name);
    n_items = 60;
  endfunction
  task body();
    aes_item tr;
    repeat (n_items) begin
      tr = aes_item::type_id::create("tr");   
      start_item(tr);
      if (!tr.randomize())
        `uvm_error(get_type_name(), "randomize failed")
      finish_item(tr);
    end
  endtask
endclass

// ----- KAT -----
class aes_kat_seq extends aes_base_seq;
  `uvm_object_utils(aes_kat_seq)
  function new(string name = "aes_kat_seq"); super.new(name); endfunction
  task body();
    // FIPS-197 C.1
    send(1'b0, 128'h00112233445566778899aabbccddeeff,
               128'h000102030405060708090a0b0c0d0e0f, 2);
    send(1'b1, 128'h69c4e0d86a7b0430d8cdb78070b4c55a,
               128'h000102030405060708090a0b0c0d0e0f, 2);
    // FIPS-197 Appendix B
    send(1'b0, 128'h3243f6a8885a308d313198a2e0370734,
               128'h2b7e151628aed2a6abf7158809cf4f3c, 1);
    send(1'b1, 128'h3925841d02dc09fbdc118597196a0b32,
               128'h2b7e151628aed2a6abf7158809cf4f3c, 1);
    // khoa va du lieu toan 0
    send(1'b0, 128'h0, 128'h0, 3);
    send(1'b1, 128'h66e94bd4ef8a2c3b884cfa59ca342b2e, 128'h0, 3);
  endtask
endclass

// ----- patterns ----
class aes_pattern_seq extends aes_base_seq;
  `uvm_object_utils(aes_pattern_seq)
  function new(string name = "aes_pattern_seq"); super.new(name); endfunction
  task body();
    bit [127:0] pats[$];
    pats.push_back(128'h0);
    pats.push_back({128{1'b1}});
    pats.push_back({64{2'b01}});
    pats.push_back({64{2'b10}});
    pats.push_back(128'h1);
    pats.push_back(128'h8000_0000_0000_0000_0000_0000_0000_0000);
    pats.push_back({16{8'hff}} ^ 128'h1);
    pats.push_back(128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef);

    foreach (pats[i]) begin
      foreach (pats[j]) begin
        if ((i + j) % 3 == 0) begin     
          send(1'b0, pats[i], pats[j], 1);
          send(1'b1, pats[i], pats[j], 1);
        end
      end
    end
  endtask
endclass

// ------ same key -----
class aes_same_key_seq extends aes_base_seq;
  `uvm_object_utils(aes_same_key_seq)
  rand bit [127:0] fixed_key;
  function new(string name = "aes_same_key_seq");
    super.new(name);
    n_items = 40;
  endfunction
  task body();
    aes_item tr;
    if (!this.randomize(fixed_key))    
      `uvm_error(get_type_name(), "randomize failed")
    repeat (n_items) begin
      tr = aes_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { key == fixed_key; })
        `uvm_error(get_type_name(), "randomize failed")
      finish_item(tr);
    end
  endtask
endclass

//----- mode toggle -----
class aes_mode_toggle_seq extends aes_base_seq;
  `uvm_object_utils(aes_mode_toggle_seq)
  function new(string name = "aes_mode_toggle_seq");
    super.new(name);
    n_items = 40;
  endfunction
  task body();
    aes_item tr;
    bit      m = 1'b0;
    repeat (n_items) begin
      tr = aes_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { mode == m; gap inside {[0:1]}; })
        `uvm_error(get_type_name(), "randomize failed")
      finish_item(tr);
      m = ~m;
    end
  endtask
endclass

// ------ round trip ------
class aes_roundtrip_seq extends aes_base_seq;
  `uvm_object_utils(aes_roundtrip_seq)
  function new(string name = "aes_roundtrip_seq");
    super.new(name);
    n_items = 20;
  endfunction
  task body();
    bit [127:0] k, p, c;
    repeat (n_items) begin
      k = {$urandom(), $urandom(), $urandom(), $urandom()};
      p = {$urandom(), $urandom(), $urandom(), $urandom()};
      aes128_enc_ref(k, p, c);          // mo hinh dung stimulus
      send(1'b0, p, k, 1);              // DUT ma hoa  -> cho c
      send(1'b1, c, k, 0);              // DUT giai ma  -> cho p
    end
  endtask
endclass