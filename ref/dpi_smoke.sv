module dpi_smoke;

  import "DPI-C" function void aes128_enc_ref(input  bit [127:0] key,
                                              input  bit [127:0] pt,
                                              output bit [127:0] ct);

  import "DPI-C" function void aes128_dec_ref(input  bit [127:0] key,
                                              input  bit [127:0] ct,
                                              output bit [127:0] pt);

  bit [127:0] key, din, dout;
  int         n_fail = 0;

  task automatic chk(bit [127:0] got, bit [127:0] exp, string what);
    if (got !== exp) begin
      n_fail++;
      $display("  FAIL %s", what);
      $display("       got %h", got);
      $display("       exp %h", exp);
    end
    else $display("  ok   %s", what);
  endtask

  initial begin
    $display("==== dpi_smoke ====");

    key = 128'h000102030405060708090a0b0c0d0e0f;
    din = 128'h00112233445566778899aabbccddeeff;
    aes128_enc_ref(key, din, dout);
    chk(dout, 128'h69c4e0d86a7b0430d8cdb78070b4c55a, "enc vector A");

    din = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    aes128_dec_ref(key, din, dout);
    chk(dout, 128'h00112233445566778899aabbccddeeff, "dec vector A");

    key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    din = 128'h3243f6a8885a308d313198a2e0370734;
    aes128_enc_ref(key, din, dout);
    chk(dout, 128'h3925841d02dc09fbdc118597196a0b32, "enc vector B");

    key = '0; din = '0;
    aes128_enc_ref(key, din, dout);
    chk(dout, 128'h66e94bd4ef8a2c3b884cfa59ca342b2e, "enc all-zero");

    begin
      bit [127:0] k2, p2, c2, b2;
      int errs = 0;
      for (int i = 0; i < 200; i++) begin
        k2 = {$urandom(), $urandom(), $urandom(), $urandom()};
        p2 = {$urandom(), $urandom(), $urandom(), $urandom()};
        aes128_enc_ref(k2, p2, c2);
        aes128_dec_ref(k2, c2, b2);
        if (b2 !== p2) errs++;
      end
      if (errs != 0) begin
        n_fail++;
        $display("  FAIL round trip: %0d of 200 wrong", errs);
      end
      else $display("  ok   round trip 200/200");
    end

    if (n_fail == 0) $display("*** DPI SMOKE PASSED ***");
    else             $display("*** DPI SMOKE FAILED (%0d) ***", n_fail);
    $finish;
  end

endmodule