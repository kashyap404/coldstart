# coldstart

Some designs only work because the FPGA powers up in a known state.
`coldstart` checks for that.

It runs CIRCT bounded model checking on the same RTL twice. The first run
uses the FPGA power-up values. The second run lets every register start in
any state. If the result changes, the design depends on a value it never
sets itself.

The check stops at CIRCT's HW/Comb/Seq IR. It does not synthesize the design
and does not need a gate netlist.

## Quick start

You need `circt-verilog`, `circt-bmc`, the Z3 shared library, and Python 3.9
or newer.

```sh
export CIRCT_BIN=/path/to/circt/bin
export Z3_LIB=/path/to/libz3.dylib   # optional
make check
```

The script looks for CIRCT at `--circt-bin`, `$CIRCT_BIN`, `.tools/circt/bin`,
then `$PATH`. It looks for Z3 at `--z3-lib`, `$Z3_LIB`, `brew --prefix z3`,
then the usual library paths. It does not download anything.

If you do not have CIRCT, download a prebuilt release from
<https://github.com/llvm/circt/releases>. Put its `bin` directory on `PATH`,
or unpack it under `.tools/circt`. You can also put local paths in
`local.mk`. Git ignores that file.

`make list` shows the cases. `make check-case CASE=pipe5` runs one, and
`make cex CASE=pipe5` prints its no-init counterexample.

## Results

The checks below use bound 12:

| Design | Class | Property | With init | Without init | Fixed |
|---|---|---|---|---|---|
| `pipe5` | structural | output valid implies the pipeline was fed | PASS | FAIL | PASS |
| `decade_counter` | unrecoverable | `cnt <= 9` | PASS | FAIL | PASS |
| `ring_fsm` | unrecoverable | state is exactly one-hot | PASS | FAIL | PASS |
| `fifo_count` | redundant state | `count == wr_ptr - rd_ptr` | PASS | FAIL | PASS |
| `gray_counter` | redundant state | `gray == enc(bin)` | PASS | FAIL | PASS |
| `grant_arbiter` | transient | grants are never both asserted | PASS | FAIL | PASS |
| `robust_counter` | control | `safe <= 9` | PASS | PASS | - |

PASS means the tool found no violation up to the bound. It is not a proof.
The bounds are in `cases.json`.

## The pipeline case

`rtl/cases/pipe5.sv` is a five-stage valid pipeline with no reset.

```systemverilog
logic [4:0] v `INIT(5'b0);

always_ff @(posedge clk)
  v <= {v[3:0], in_valid};

assign out_valid = v[4];
```

With a zero power-up value, the output can only become valid after five
cycles of `in_valid`. If the register can start in any state, `v` may
already have a bit set:

```text
counterexample for pipe5:
cycle 0:
  in_valid = 0x0
  v_state = 0x8
  seen_in_state = 0x0
cycle 1:
  in_valid = 0x0
  v_state = 0x10
  seen_in_state = 0x0
Assertion can be violated!
```

A token reached the output even though no input arrived. The fixed version
in `rtl/fixed/pipe5.sv` adds a two-cycle power-on reset. The same property
then passes in both runs. The other designs follow the same pattern: find
the bug, add a reset, check again.

## How it works

For each case, the script compiles the RTL twice:

```sh
circt-verilog --ir-hw --top=<module> [-DNO_INIT] -I rtl rtl/por_reset.sv \
  <case>.sv -o build/<case>/<mode>.mlir
circt-bmc -b <bound> --module=<module> --run --shared-libs=<libz3> \
  build/<case>/<mode>.mlir
```

`rtl/fpga_init.svh` defines `INIT(v)` as `= v` by default. Under
`-DNO_INIT`, it defines it as nothing. Only design state uses this macro.
Checker state is always initialized.

`--top` tells `circt-bmc` which module to check. Without it, the tool may try
to lower assertions in modules that are not used.

## Related work

This problem is not new. DVCon has a paper on [reset and initialization
checks](https://dvcon-proceedings.org/wp-content/uploads/reset-and-initialization-the-good-the-bad-and-the-ugly.pdf).
A 2002 ASIC paper uses [formal methods to find uninitialized
registers](https://doi.org/10.1109/asic.2002.1158031). [DenseChip
explains](https://densechip.com/topics/formal/fpv-foundations/reset-and-initial-state/free-initial-state-and-the-reset-sequence)
why the first state can be anything and why a reset assumption is needed.
[SymbiYosys](https://yosyshq.readthedocs.io/projects/ap011/en/latest/unexpected.html)
also starts from an arbitrary state and needs an explicit reset assumption.
[Verilator's `--x-initial`
option](https://veripool.org/guide/latest/exe_verilator.html) randomizes
uninitialized state in simulation, so it finds some of these bugs but does
not cover every state.

`coldstart` does not add a new solver. Its job is the two runs and the
comparison.

## Limits

- **Bounded, not proven.** Bound 12 finds these bugs. It does not prove they are absent.
- **One clock.** CDC checks need a different model.
- **Clocked assertions.** A clocked assertion does not see the state before the first edge. `grant_arbiter` uses a sticky monitor to catch it.
- **Small SVA subset.** Implication (`|->`) and `$past` do not lower in this flow.
- **`case` statements.** They lower to `comb.icmp ceq`, which the SMT path rejects. The FIFO uses `if/else`.
