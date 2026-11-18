# AES-128 Design Verification (UVM, Siemens QuestaSim)

A verification environment for `aes128_top`, a bidirectional AES-128 core of my own design.
It contains a plain-Verilog bring-up testbench, a C reference model wired in through DPI-C,
a full UVM environment (driver, monitor, scoreboard, functional coverage), 11 SVA assertions,
and a set of pre-wired bugs that prove the environment actually catches failures.

- **DUT**: single-block AES-128, 128-bit key, 10 rounds, encrypt and decrypt sharing one data port.
- **Tools**: QuestaSim (`vlib`, `vlog`, `vsim`, `vcover`), the UVM library shipped with Questa,
  `gcc` for the reference model.
- **Reference standard**: FIPS-197.

> This is the QuestaSim flow. A Cadence Xcelium flow for the same source tree lives in
> `README.md`; the only differences are the run commands and two tool-specific lines noted in
> section 6.

---

## 1. Directory structure

```
aes128_dv/
├── README.md              Xcelium flow
├── README_questa.md       this file
├── .gitignore
├── rtl/                   DUT RTL, 11 files, never edited by the testbench
│   ├── sbox.v
│   ├── aes_inv_sbox.v
│   ├── mixcolumns.v
│   ├── inv_mixcolumns.v
│   ├── key_expansion.v
│   ├── inv_key_expansion.v
│   ├── encrypt_round.v
│   ├── decrypt_round.v
│   ├── aes128_encrypt.v
│   ├── aes128_decrypt.v
│   └── aes128_top.v
├── ref/
│   ├── aes_ref.c          AES-128 reference model (encrypt + decrypt) + DPI bridge
│   └── dpi_smoke.sv       proves the C model is reachable from SV with the right byte order
├── bringup/
│   └── tb_bringup.sv      Stage 0: plain Verilog, 13 checks, no UVM
├── tb/
│   ├── aes_dut_wrap.sv    wrapper around the DUT, holds the bug-injection switches
│   ├── aes_if.sv          interface, two clocking blocks, do_reset task
│   ├── aes_sva.sv         11 assertions + 7 cover properties, bound to the wrapper
│   └── tb_top.sv          UVM top: clock, DUT, config_db, run_test
├── env/
│   ├── aes_pkg.sv         package, DPI declarations, include order
│   ├── aes_item.sv        transaction: mode, data_in, key, gap
│   ├── aes_item_tight.sv  derived item constrained to gap == 0, used by factory override
│   ├── aes_config.sv      expected latencies and knobs
│   ├── aes_driver.sv      drives the start/busy handshake
│   ├── aes_monitor.sv     pairs start with done, spots ignored starts
│   ├── aes_agent.sv
│   ├── aes_scoreboard.sv  compares the DUT against the C model
│   ├── aes_coverage.sv    cg_txn + 16 instances of cg_sbox_byte
│   └── aes_env.sv
├── seq/
│   └── aes_seq_lib.sv     7 sequences: kat, random, pattern, same_key, mode_toggle, roundtrip
├── test/
│   └── aes_test_lib.sv    9 tests
└── sim/
    ├── rtl.f              RTL file list
    └── tb.f               testbench file list and include directories
```

### 1.1 File lists

`sim/rtl.f`:

```
../rtl/sbox.v
../rtl/aes_inv_sbox.v
../rtl/mixcolumns.v
../rtl/inv_mixcolumns.v
../rtl/key_expansion.v
../rtl/inv_key_expansion.v
../rtl/encrypt_round.v
../rtl/decrypt_round.v
../rtl/aes128_encrypt.v
../rtl/aes128_decrypt.v
../rtl/aes128_top.v
```

`sim/tb.f`:

```
+incdir+../env
+incdir+../seq
+incdir+../test
../tb/aes_dut_wrap.sv
../tb/aes_if.sv
../env/aes_pkg.sv
../tb/aes_sva.sv
../tb/tb_top.sv
```

Two lists rather than one, because the RTL is plain Verilog-2001 and the testbench is
SystemVerilog. Keeping them apart means `-sv` is applied only where it belongs, so the RTL is
never reinterpreted under SystemVerilog rules.

---

## 2. DUT specification, the parts that matter

### 2.1 Port list

| Port | Dir | Width | Meaning |
| --- | --- | --- | --- |
| `clk` | in | 1 | All state changes on the rising edge |
| `rst_n` | in | 1 | **Synchronous** reset, active low |
| `start` | in | 1 | Request one operation |
| `mode` | in | 1 | 0 encrypt, 1 decrypt |
| `data_in` | in | 128 | Plaintext when `mode=0`, ciphertext when `mode=1` |
| `key` | in | 128 | AES-128 key, each transaction carries its own |
| `data_out` | out | 128 | Result, valid only while `done=1` |
| `done` | out | 1 | Pulse exactly one cycle wide |
| `busy` | out | 1 | DUT is computing, `start` is ignored |

Byte order: FIPS-197 byte 0 sits at bits `[127:120]`, the two leftmost hex digits. FIPS vectors go
into `data_in` and `key` verbatim, with no byte swapping.

### 2.2 Cycle-counting convention

This is the easiest thing to get wrong, so it is defined tightly:

> The **accepting edge (edge 0)** is the rising edge at which the **sampled value** of `start` is 1
> and of `busy` is 0. Later edges are numbered 1, 2, 3… Latency L is the index of the first edge at
> which the sampled value of `done` is 1.

"Sampled value" means the value immediately **before** the edge, exactly what a clocking block with
`input #1step` sees and exactly what SVA sees. Measuring with a small delay after the edge
(`@(posedge clk); #1;`) yields a number one lower. This whole repository uses the sampled-value
convention.

| Property | `mode=0` encrypt | `mode=1` decrypt |
| --- | --- | --- |
| Latency L | 10 cycles | 21 cycles |
| `busy` sampled high at edges | 1 through 9 | 1 through 20 |
| `done` sampled high at edge | 10 | 21 |
| Peak throughput | 1 block / 10 cycles | 1 block / 21 cycles |

Decrypt takes almost twice as long because the FSM runs two phases: 10 cycles expanding the key
forward from rk0 up to rk10, then 10 cycles decrypting while walking the key back down to rk0,
plus one load cycle. Latency does not depend on the data or the key.

### 2.3 Handshake rules

1. The DUT accepts a request if and only if `start=1` and `busy=0` at the same rising edge.
2. A `start` raised while `busy=1` is ignored completely; the operation in flight is unaffected.
3. `mode`, `data_in` and `key` only need to be stable **at the accepting edge**. Immediately after
   it they may change freely, X included, because the DUT has latched everything it needs.
4. `busy` and `done` are never both high. `busy` drops in the same cycle `done` rises.
5. A new request is therefore accepted on the `done` edge itself. That is the tightest
   back-to-back case.
6. Holding `start=1` continuously makes the DUT run operations back to back without idling.

### 2.4 Output and reset rules

1. `data_out` is forced to `128'h0` whenever `done=0`. The result is readable for exactly one
   cycle, so whoever uses the DUT must latch it.
2. `done` picks its direction from the `mode` captured at the accepting edge, not the current
   `mode`.
3. `rst_n` is synchronous: it must be held low across at least one rising edge to take effect.
4. A reset in mid-operation cancels it **silently**: no `done` pulse, no error flag. The testbench
   must therefore drop any pending expectation on reset.
5. After reset: `data_out=0`, `done=0`, `busy=0`, and the DUT accepts a new request on the next edge.

### 2.5 Four confirmed design choices

The four properties below were read out of the RTL, not out of FIPS-197. They are design choices,
confirmed as intentional before being turned into assertions:

- Holding `start` high runs operations continuously, instead of requiring a one-cycle pulse.
- `data_out` is forced to 0 when `done=0`, instead of holding the previous result.
- A reset in mid-operation cancels the transaction silently.
- A `start` during `busy` is dropped with no indication.

### 2.6 Requirement list

These REQ tags run through the coverage model and the assertions, so every line of the spec is
traceable to the place that checks it.

| Tag | Requirement | Checked by |
| --- | --- | --- |
| REQ-FUNC-01 | Encryption matches FIPS-197 | scoreboard + `aes_kat_test` |
| REQ-FUNC-02 | Decryption matches FIPS-197 | scoreboard + `aes_kat_test` |
| REQ-FUNC-03 | Decrypting a ciphertext returns the original plaintext | `aes_roundtrip_test` |
| REQ-FUNC-04 | Two adjacent transactions with different keys both stay correct | `aes_b2b_test` |
| REQ-FUNC-05 | `data_in` and `key` need only be stable at the accepting edge | driver drives X + scoreboard |
| REQ-TIME-01 | Encrypt latency is exactly 10 | SVA + scoreboard |
| REQ-TIME-02 | Decrypt latency is exactly 21 | SVA + scoreboard |
| REQ-TIME-03 | Latency is data-independent | latency coverpoint + scoreboard |
| REQ-TIME-04 | `done` is exactly one cycle wide | SVA |
| REQ-HS-01 | A request is accepted iff `start && !busy` | monitor + SVA |
| REQ-HS-02 | A `start` during `busy` is ignored | `aes_b2b_test` |
| REQ-HS-03 | `busy` is high from edge 1 to L-1 | SVA |
| REQ-HS-04 | `busy` and `done` are mutually exclusive | SVA |
| REQ-HS-05 | A new request is accepted on the `done` edge | `aes_b2b_test` + coverage |
| REQ-OUT-01 | `data_out=0` while `done=0` | SVA |
| REQ-OUT-02 | `data_out` is valid at the `done` edge | scoreboard |
| REQ-OUT-03 | `done` follows the captured `mode` | `aes_mode_toggle_test` |
| REQ-RST-01 | Reset is synchronous, needs at least one edge | `tb_bringup` |
| REQ-RST-02 | A mid-operation reset cancels with no `done` | `aes_reset_test` |
| REQ-RST-03 | After reset the DUT is idle and the output is zero | `aes_reset_test` |

---

## 3. The verification environment

### 3.1 Reference model

`ref/aes_ref.c` implements AES-128 straight from the FIPS-197 pseudo-code, fully independent of the
RTL. Rewriting AES in SystemVerilog would make it far too easy to carry over the same reasoning
used when writing the RTL, mistakes included. Writing it in C and checking it with `gcc` before it
ever reaches the simulator keeps the two genuinely independent.

The file exports two DPI functions, `aes128_enc_ref` and `aes128_dec_ref`, plus a self-check mode
enabled with `-DAES_STANDALONE`.

### 3.2 Decisions worth explaining

- **The driver calls `item_done()` at the accepting edge**, not at `done`. That lets the sequencer
  hand over the next request while the current operation is still running. Pairing start with done
  is the monitor's job.
- **With `gap == 0` the driver raises `start` even while the DUT is busy.** The DUT ignores it and
  then accepts it on the `done` edge. This reaches the tightest back-to-back spacing without the
  driver needing to know the latency. A driver that counted 10 or 21 cycles to line up `start`
  would be assuming the very thing the testbench is supposed to check.
- **The monitor handles `done` before it handles acceptance**, because a new request can be accepted
  on the same edge that retires the previous one. The other order makes the monitor report "two
  requests at once" in every back-to-back test.
- **The monitor drops its pending expectation on reset**, because the DUT cancels silently
  (REQ-RST-02).
- **The driver drives `data_in`, `key` and `mode` to X after the accepting edge** to demonstrate
  REQ-FUNC-05. If someone later changes the RTL to read `data_in` mid-operation, the X shows up
  immediately instead of on real silicon.
- **`aes_b2b_test` uses a factory override** rather than a separate sequence: it tells the factory
  that every `aes_item` should come back as `aes_item_tight`, whose constraint forces `gap == 0`.
  The random sequence is reused without touching a line of it.
- **The assertions call `uvm_report_error` instead of `$error`**, so UVM counts them and
  `report_phase` reaches the right verdict.

### 3.3 The nine tests

| Test | Sequence | Requirements it closes |
| --- | --- | --- |
| `aes_kat_test` | `aes_kat_seq` | FUNC-01, FUNC-02, TIME-01, TIME-02 |
| `aes_random_test` | `aes_random_seq`, 80–160 items | FUNC-01/02, TIME-03 |
| `aes_pattern_test` | `aes_pattern_seq` | FUNC-01/02 at corner values |
| `aes_same_key_test` | `aes_same_key_seq` | state leaking between operations |
| `aes_b2b_test` | `aes_random_seq` + factory override | HS-02, HS-05, FUNC-04 |
| `aes_mode_toggle_test` | `aes_mode_toggle_seq` | OUT-03 |
| `aes_roundtrip_test` | `aes_roundtrip_seq` | FUNC-03 |
| `aes_reset_test` | 3 sequences + a reset mid-traffic | RST-02, RST-03 |
| `aes_all_test` | 6 sequences back to back | coverage closure |

### 3.4 Functional coverage

- `cg_txn`: direction, latency, gap between transactions, data pattern, key pattern, direction
  transitions, plus two crosses, `dir × din` and `dir × gap`.
- `cg_sbox_byte` × 16 instances: 256 bins for each byte position of the first-round S-box input,
  encrypt only, where that byte is `data_in[i] ^ key[i]`. Switch it off through
  `aes_config::enable_sbox_cov` for short smoke runs.

---

## 4. Commands

Every command runs from `sim/`, except the reference-model build, which says otherwise.

### 4.1 Environment check

```bash
# Put QuestaSim on PATH (the exact path depends on your installation)
export PATH=$QUESTA_HOME/bin:$PATH

# Check the tools are reachable
which vlib vlog vsim vcover

# gcc and the libc headers are needed: the reference model is written in C
gcc --version
ls /usr/include/string.h
```

On RHEL/Rocky-family distributions, install the compiler with:

```bash
sudo dnf install -y gcc glibc-devel
```

### 4.2 Create the work library

Done once per working directory. `vlib` creates the library, `vmap` maps the logical name to it.

```bash
vlib work
vmap work work
```

### 4.3 Check the C reference model outside the simulator

This runs the model's AES against the FIPS-197 vectors with no simulator involved. Debugging a C
function with `printf` takes seconds; debugging the same mistake once it is hidden behind a UVM
scoreboard takes an afternoon.

```bash
cd ../ref
gcc -DAES_STANDALONE -O2 -Wall -Wextra -o aes_ref aes_ref.c
./aes_ref
cd ../sim
```

Expected output: `enc vector N ok` and `dec vector N ok` lines, `round trip: 2000/2000 ok`, and a
final `REF PASSED`.

### 4.4 Build the DPI shared library

Questa can compile a `.c` file given to `vlog` directly, but building the library explicitly keeps
the C step visible: a compile error shows up on the terminal instead of inside a simulator log.

```bash
# Questa ships svdpi.h in its include directory
ls $QUESTA_HOME/include/svdpi.h

gcc -shared -fPIC -O2 -m64 \
    -I$QUESTA_HOME/include \
    -o libaes_ref.so ../ref/aes_ref.c

# Confirm the library is a 64-bit object
file libaes_ref.so
```

Rebuild only when `aes_ref.c` changes. The library must match the simulator's word size: a 32-bit
object loaded into a 64-bit `vsim` fails at load time with a linker error.

### 4.5 Stage 0: the plain-Verilog bring-up testbench

This proves clock, reset, handshake and latency all behave before a single line of UVM exists. No
UVM, no DPI.

```bash
# Compile the RTL as Verilog, and the two testbench files as SystemVerilog
vlog -f rtl.f
vlog -sv ../tb/aes_dut_wrap.sv ../bringup/tb_bringup.sv

# Run in console mode and quit when the testbench finishes
vsim -c work.tb_bringup \
     -voptargs=+acc \
     -l bringup.log \
     -do "run -all; quit -f"
```

| Flag | Meaning |
| --- | --- |
| `vlog -f <file>` | read the file list from a file |
| `vlog -sv` | compile these files as SystemVerilog |
| `vsim -c` | console mode, no GUI |
| `work.tb_bringup` | the top module, inside library `work` |
| `-voptargs=+acc` | keep signal visibility, needed for waveforms and some checks |
| `-l <file>` | write the transcript to a log file |
| `-do "run -all; quit -f"` | run to completion, then exit |

Expected result: `*** BRINGUP PASSED *** (13 checks)`.

### 4.6 Stage 0b: prove the testbench catches bugs

A testbench that only ever passes proves nothing. One that passes when the design is clean and
fails when a bug is injected is worth trusting. `tb/aes_dut_wrap.sv` carries three bug switches,
enabled with `vlog +define+`.

```bash
# Bug 1: done stays high for 2 cycles instead of 1
vlog -sv +define+WRAP_BUG_DONE_WIDE ../tb/aes_dut_wrap.sv ../bringup/tb_bringup.sv
vsim -c work.tb_bringup -l bug_done_wide.log -do "run -all; quit -f"

# Bug 2: data_out is delayed one cycle, so at the done edge it still holds the old value
vlog -sv +define+WRAP_BUG_LATE_DATA ../tb/aes_dut_wrap.sv ../bringup/tb_bringup.sv
vsim -c work.tb_bringup -l bug_late_data.log -do "run -all; quit -f"

# Bug 3: data_out holds the previous result instead of being forced to 0 when done=0
vlog -sv +define+WRAP_BUG_NO_GATE ../tb/aes_dut_wrap.sv ../bringup/tb_bringup.sv
vsim -c work.tb_bringup -l bug_no_gate.log -do "run -all; quit -f"

# Confirm the macro really reached the compiler, and count the red checks
grep -E "\[WRAP\]|pass =|fail =" bug_*.log

# Recompile clean before moving on
vlog -sv ../tb/aes_dut_wrap.sv ../bringup/tb_bringup.sv
```

The wrapper prints a `[WRAP] ... is ON` line at time zero, which is how you confirm the define
arrived rather than guessing from the check results. In Questa, `+define+` is a `vlog` argument,
not a `vsim` one: a define passed to `vsim` has no effect because compilation already happened.
Recompiling the wrapper is what switches a bug on or off, so each of the commands above starts with
its own `vlog`.

### 4.7 Stage 1: check DPI inside the simulator

This confirms that the simulator can call the C functions and that 128-bit values cross the
boundary with the right byte order. Keeping it separate from UVM means a failure here points at the
C linkage, not at the scoreboard.

```bash
vlog -sv ../ref/dpi_smoke.sv

vsim -c work.dpi_smoke \
     -sv_lib ./libaes_ref \
     -l dpi_smoke.log \
     -do "run -all; quit -f"
```

| Flag | Meaning |
| --- | --- |
| `-sv_lib ./libaes_ref` | load the DPI library built in 4.4 |

Note the library name carries **no `.so` extension**: `vsim` appends the platform's own extension.
Writing `-sv_lib ./libaes_ref.so` is a common cause of a "cannot find library" message.

Expected result: five `ok` lines, then `*** DPI SMOKE PASSED ***`.

### 4.8 Stages 2 to 7: run one UVM test with coverage

Compile once, then run as many tests as you like against the same compiled library. Questa ships a
precompiled UVM, so the UVM sources need no `+incdir+` and no separate library: importing
`uvm_pkg` is enough.

```bash
mkdir -p logs cov

# Compile the RTL (Verilog) with code coverage instrumentation
vlog -f rtl.f +cover=sbcef

# Compile the testbench (SystemVerilog). No coverage instrumentation here:
# code coverage belongs to the DUT, not to the testbench.
vlog -sv -f tb.f

# Run one test
vsim -c work.tb_top \
     -sv_lib ./libaes_ref \
     -voptargs=+acc \
     -coverage \
     -sv_seed 1 \
     +UVM_TESTNAME=aes_kat_test \
     +UVM_VERBOSITY=UVM_MEDIUM \
     +UVM_MAX_QUIT_COUNT=10 \
     -l logs/aes_kat_test_s1.log \
     -do "coverage attribute -name TESTNAME -value aes_kat_test_s1; \
          coverage save -onexit cov/aes_kat_test_s1.ucdb; \
          run -all; \
          quit -f"
```

Flag by flag:

| Flag | Meaning |
| --- | --- |
| `vlog +cover=sbcef` | instrument for code coverage: `s` statement, `b` branch, `c` condition, `e` expression, `f` FSM |
| `vlog -sv` | compile as SystemVerilog |
| `vsim -c` | console mode |
| `work.tb_top` | the UVM top module |
| `-sv_lib ./libaes_ref` | load the C reference model |
| `-voptargs=+acc` | preserve visibility through the optimizer |
| `-coverage` | collect coverage during this run |
| `-sv_seed <n>` | seed for randomization; change it for different stimulus |
| `+UVM_TESTNAME=<test>` | select the test, this is how UVM knows which class to run |
| `+UVM_VERBOSITY=<level>` | log detail: `UVM_LOW`, `UVM_MEDIUM`, `UVM_HIGH`, `UVM_FULL` |
| `+UVM_MAX_QUIT_COUNT=10` | stop after 10 errors instead of flooding the log |
| `-l <file>` | transcript file |
| `coverage attribute -name TESTNAME -value <name>` | give this run a unique name in the database |
| `coverage save -onexit <file>.ucdb` | write the coverage database when the run ends |
| `run -all` | run until the testbench finishes |

The `TESTNAME` attribute matters: merging two UCDB files that carry the same test record name is
reported as a merge error, so every run needs its own name. Setting it explicitly, instead of
relying on the default, makes the regression loop below safe.

The nine tests available:

```
aes_kat_test          aes_random_test       aes_pattern_test
aes_same_key_test     aes_b2b_test          aes_mode_toggle_test
aes_roundtrip_test    aes_reset_test        aes_all_test
```

Common variations:

```bash
# A different test and a different seed
vsim -c work.tb_top -sv_lib ./libaes_ref -coverage -sv_seed 7 \
     +UVM_TESTNAME=aes_random_test -l logs/aes_random_test_s7.log \
     -do "coverage attribute -name TESTNAME -value aes_random_test_s7; \
          coverage save -onexit cov/aes_random_test_s7.ucdb; run -all; quit -f"

# Verbose logging, every transaction printed, for debug
vsim ... +UVM_VERBOSITY=UVM_HIGH ...

# Interactive GUI, stop at the first error and look around
vsim work.tb_top -sv_lib ./libaes_ref -voptargs=+acc \
     +UVM_TESTNAME=aes_kat_test -do "add log -r /*; run -all"
```

### 4.9 Run the whole regression

Directed tests need one seed because their stimulus is fixed; random tests deserve several.

```bash
mkdir -p logs cov

run_one () {
  local t=$1 s=$2
  vsim -c work.tb_top \
       -sv_lib ./libaes_ref \
       -coverage -sv_seed $s \
       +UVM_TESTNAME=$t +UVM_MAX_QUIT_COUNT=10 \
       -l logs/${t}_s${s}.log \
       -do "coverage attribute -name TESTNAME -value ${t}_s${s}; \
            coverage save -onexit cov/${t}_s${s}.ucdb; \
            run -all; quit -f"
}

# Directed tests: one seed each
for t in aes_kat_test aes_pattern_test aes_roundtrip_test; do
  run_one $t 1
done

# Random tests: three seeds each
for t in aes_random_test aes_same_key_test aes_b2b_test \
         aes_mode_toggle_test aes_reset_test aes_all_test; do
  for s in 1 2 3; do
    run_one $t $s
  done
done

# Verdict: a test passes only if the banner is there AND no error line is
grep -l '\*\*\* TEST PASSED \*\*\*' logs/*.log | wc -l
grep -h -E '^# \*\* (Error|Fatal)' logs/*.log | sort -u
grep -h 'UVM_ERROR' logs/*.log | grep -v ': *0' | sort -u
```

Check both conditions, not just the banner. An SVA failure or a `uvm_error` raised after
`report_phase` slips past a search for `TEST PASSED` alone.

### 4.10 Merge and read the coverage

```bash
# Merge every database from the regression into one
vcover merge cov/merged.ucdb cov/*.ucdb

# Text reports
vcover report -details -output cov/summary.rpt cov/merged.ucdb
vcover report -details -cvg -output cov/covergroup.rpt cov/merged.ucdb
vcover report -details -assert -output cov/assertion.rpt cov/merged.ucdb

# HTML report, easier for finding holes
vcover report -html -htmldir cov/html -details cov/merged.ucdb
```

| Command | Meaning |
| --- | --- |
| `vcover merge <out> <in...>` | merge several UCDB files; the output name comes first |
| `vcover report -details` | per-bin detail instead of a bare percentage |
| `-cvg` | covergroups only |
| `-assert` | assertions and cover properties only |
| `-html -htmldir <dir>` | browsable HTML instead of text |
| `-output <file>` | write to a file rather than the transcript |

Open the merged database in the GUI to browse it interactively:

```bash
vsim -viewcov cov/merged.ucdb &
```

### 4.11 Waveforms

Questa writes a WLF file. Log the signals during the run, then view the file afterwards:

```bash
# Record everything during the run
vsim -c work.tb_top -sv_lib ./libaes_ref -voptargs=+acc \
     +UVM_TESTNAME=aes_kat_test \
     -wlf waves.wlf \
     -do "add log -r /*; run -all; quit -f"

# Look at it later
vsim -view waves.wlf &
```

`-voptargs=+acc` is required: without it the optimizer may remove the very signals you want to see.

### 4.12 Clean up

```bash
rm -rf work transcript *.wlf *.log *.ucdb cov logs libaes_ref.so \
       modelsim.ini vsim.dbg .visualizer
vlib work
```

Deleting `work` is the Questa equivalent of a full rebuild; `vdel -all` does the same thing from
inside the tool.

---

## 5. Results

Fill this section with measured numbers after a regression run.

### 5.1 Test results

| Test | Seeds | Verdict | Transactions checked |
| --- | --- | --- | --- |
| `aes_kat_test` | 1 | | |
| `aes_random_test` | 1–3 | | |
| `aes_pattern_test` | 1 | | |
| `aes_same_key_test` | 1–3 | | |
| `aes_b2b_test` | 1–3 | | |
| `aes_mode_toggle_test` | 1–3 | | |
| `aes_roundtrip_test` | 1 | | |
| `aes_reset_test` | 1–3 | | |
| `aes_all_test` | 1–3 | | |

### 5.2 Merged coverage

| Metric | Percentage |
| --- | --- |
| Statement | |
| Branch | |
| Condition | |
| Expression | |
| FSM | |
| `cg_txn` | |
| `cg_sbox_byte` (16 instances) | |
| Assertions | |

### 5.3 Injected bugs and the tests that caught them

| Bug | Description | Caught by | Related requirement |
| --- | --- | --- | --- |
| `WRAP_BUG_DONE_WIDE` | `done` two cycles wide | | REQ-TIME-04, REQ-HS-04 |
| `WRAP_BUG_LATE_DATA` | `data_out` delayed one cycle | | REQ-OUT-01, REQ-OUT-02 |
| `WRAP_BUG_NO_GATE` | `data_out` holds the old result while `done=0` | | REQ-OUT-01 |

---

## 6. Notes for this flow

### 6.1 One source change needed for Questa

`tb/tb_top.sv` uses `$shm_open` and `$shm_probe`, which are Cadence system tasks and do not exist
in Questa. Guard them so the same file works under both tools; Questa predefines the `QUESTA`
macro, Xcelium does not:

```systemverilog
  initial begin
    uvm_config_db #(virtual aes_if)::set(null, "*", "vif", vif);
    if ($test$plusargs("WAVE")) begin
`ifndef QUESTA
      $shm_open("waves.shm");
      $shm_probe("ACMTF");
`endif
    end
    run_test();
  end
```

Under Questa, waveform logging comes from the command line instead, as shown in section 4.11, so
there is nothing to put in the `ifdef` branch.

### 6.2 Other differences from the Xcelium flow

| Topic | Xcelium | Questa |
| --- | --- | --- |
| Compile and run | one `xrun` command | `vlib`, `vlog`, then `vsim` |
| Language selection | inferred from the file extension | `vlog -sv` for SystemVerilog files |
| Macro definition | `+define+X` on `xrun` | `+define+X` on `vlog` only |
| Forcing a rebuild | `-clean` | delete `work` and `vlib work` again, or `vdel -all` |
| DPI library | `-sv_lib ./libaes_ref.so` | `-sv_lib ./libaes_ref`, no extension |
| `svdpi.h` location | `<install>/tools/include` | `$QUESTA_HOME/include` |
| Seed | `-svseed <n>` | `-sv_seed <n>` |
| Signal visibility | `-access +rwc` | `-voptargs=+acc` |
| Coverage instrumentation | `-coverage all` on the run | `+cover=sbcef` at compile, `-coverage` at run |
| Coverage database | `cov_work/scope/<name>` | one `.ucdb` file per run |
| Merge and report | `imc` | `vcover merge`, `vcover report` |
| Waveform | SHM, `simvision` | WLF, `vsim -view` |

### 6.3 Things that have bitten me

- **A `+define+` on the `vsim` line does nothing.** Compilation is over by then. Recompile the file
  that reads the macro, which for the bug switches means `vlog` on `aes_dut_wrap.sv`.
- **`-sv_lib` takes the library name without `.so`.**
- **The DPI library must match the simulator's word size.** A 32-bit `.so` under a 64-bit `vsim`
  fails at load with a linker error that does not mention the word size.
- **Two UCDB files with the same `TESTNAME` make the merge fail.** Set the attribute per run, as
  section 4.8 does.
- **The include order in `aes_pkg.sv` is a dependency order.** Reordering it breaks compilation.
- **Latency is counted on sampled values.** Measuring with `@(posedge clk); #1;` yields 9 and 20
  instead of 10 and 21. Both conventions are defensible, but mixing them produces false scoreboard
  errors.
- **`rtl/` is never modified by the testbench.** Bugs are injected only in `tb/aes_dut_wrap.sv`, so
  `git diff` separates them from the design. Bugs that have to go into the RTL live on their own
  branch, never on `main`.
