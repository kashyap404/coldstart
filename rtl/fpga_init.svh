// `INIT(v)` is the power-up value in the default run and nothing under
// -DNO_INIT. Only design state uses it; checker state is always initialized.
`ifndef FPGA_INIT_SVH
`define FPGA_INIT_SVH
`ifdef NO_INIT
  `define INIT(v)
`else
  `define INIT(v) = v
`endif
`endif
