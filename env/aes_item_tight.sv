class aes_item_tight extends aes_item;

  constraint c_tight { gap == 0; }

  `uvm_object_utils(aes_item_tight)

  function new(string name = "aes_item_tight");
    super.new(name);
  endfunction

endclass
