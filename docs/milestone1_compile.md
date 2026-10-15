# Milestone 1 - DUT Compile

## DUT hierarchy (default parameters)
```
axi2apb_wrap
 |- axi2apb          (used when AXI_DATA_WIDTH == APB_DATA_WIDTH)
 |   |- axi_aw_buffer, axi_ar_buffer, axi_w_buffer, axi_r_buffer, axi_b_buffer
 |        |- axi_single_slice
 |             |- fifo
 |- axi2apb_64_32    (used when AXI_DATA_WIDTH == 64 and APB_DATA_WIDTH == 32)
     |- (same five buffers)
```
`axi_slice.sv` and `axi_slice_wrap.sv` are not instantiated by `axi2apb_wrap`
and are therefore not part of the compile list.

## File list (dependency-safe order) - `scripts/build.flist`
1. `tb/interface/axi_bus.sv`, `tb/interface/apb_bus.sv` (interfaces used by the wrapper ports)
2. `rtl/axi2apb_bridge/includes/`: `fifo.sv`, `axi_single_slice.sv`, `axi_aw_buffer.sv`,
   `axi_ar_buffer.sv`, `axi_w_buffer.sv`, `axi_r_buffer.sv`, `axi_b_buffer.sv`
3. `rtl/axi2apb_bridge/`: `axi2apb.sv`, `axi2apb_64_32.sv`, `axi2apb_wrap.sv`
4. `tb/dut_smoke_top.sv` (DUT-only top: clock, reset, idle inputs)

## Compile command (run from `scripts/`)
```
vcs -sverilog -f build.flist -ntb_opts uvm -timescale=1ns/1ps \
    -cm line+cond+fsm+tgl+branch -cm_hier cov.cfg -full64 -debug_all -l compile.log
```
Run: `cd out/build && ./simv -cm line+cond+fsm+tgl+branch -cm_name smoke_test -l smoke_test.log`

Shortcut: `make run`

## Result
- Compile and elaboration: successful with default parameters (32-bit AXI/APB data, 32-bit addresses).
- Simulation output (VCS L-2016.06_Full64):
```
[SMOKE] DUT compiled, elaborated and came out of reset. PASS
$finish at simulation time               245000
```
- The smoke top applies reset and idle inputs only. It does not exercise AXI/APB traffic;
  functional verification starts with the UVM environment.

## Testbench-only support files
`tb/interface/axi_bus.sv` and `tb/interface/apb_bus.sv` define the `AXI_BUS` / `APB_BUS`
interfaces expected by `axi2apb_wrap` (`AXI_BUS.Slave`, `APB_BUS.Master`). Signal names and widths
were taken from the wrapper port connections. No DUT file was modified.

## Note (2026-10-16)
`scripts/build.flist` now compiles `tb/tb_top.sv` (UVM testbench) and `uvm/axi2apb_pkg.sv` instead of `tb/dut_smoke_top.sv`. The smoke top stays in `tb/` as the Milestone 1 reference. The compile command above is unchanged, and `make run` now runs the UVM `bringup_test`.
