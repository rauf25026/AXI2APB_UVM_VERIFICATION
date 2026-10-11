# Milestone 2 - RTL Lint Summary

## Setup
- Tool: Synopsys VCS L-2016.06_Full64, option `+lint=all`
- Same file list as the compile flow: `scripts/build.flist`
- Run: `bash scripts/lint.sh` (log saved in `results/lint_vcs.log`)
- Top: `dut_smoke_top`, default parameters (32-bit AXI/APB data and address)
- Compile and elaboration: clean, no errors

## Result
Total messages: **36** (no errors). All reviewed below; nothing was silently waived.

| Tag | Count | Where | Category | Disposition |
|-----|-------|-------|----------|-------------|
| Lint-[VCDE] compiler directive | 19 | axi_bus, apb_bus, fifo, axi2apb, axi2apb_64_32, dut_smoke_top | Tool information | Informational only (`define / ifndef / endif / timescale). No action. |
| Lint-[SVA-UA] unnamed assertion | 8 | fifo.sv lines 139, 143 (4 instances) | DUT style | Assertions have no label. Not a functional issue. They report `$warning` if the FIFO is pushed when full or popped when empty; watch for this during simulation. |
| Lint-[UI] unused input `PSLVERR` | 1 | axi2apb.sv line 93 | **Genuine DUT observation** | PSLVERR is never used by the bridge. Matches spec section 4. BRESP/RRESP stay OKAY. To be covered by the PSLVERR directed test and documented in the final report. DUT not modified. |
| Lint-[UI] unused input `testmode_i` | 4 | fifo.sv line 23 | DUT, DFT feature | Test-mode clock-gating bypass input is not used inside the FIFO. Harmless. `test_en_i` is tied to 0 in our testbench. |
| Lint-[NS] null statement | 1 | axi2apb.sv line 379 | DUT, cosmetic | Double semicolon `;;` after the ARADDR assignment. No functional effect. DUT not modified. |
| Lint-[NS] null statement | 2 | dut_smoke_top.sv lines 67, 69 | Testbench | Event-control statements (`@(posedge clk);`). Harmless. |
| Warning-[INTFDV] selective VCD dump | 1 | dut_smoke_top.sv (`$dumpvars`) | Testbench / tool | VCS does not support selective VCD dumping of interfaces, so interface waveforms may be incomplete in the smoke run. Will use VPD/FSDB or full dump in the UVM top. |

Also reported by the tool: `Notice: Ports coerced to inout` (tool notice about interface ports, no action).

## Findings that feed the verification plan
1. PSLVERR is ignored by the bridge (confirmed by lint and by the spec).
2. FIFO assertions can fire at run time if the buffers over/underflow; check simulation logs for them.

## Limitations of this lint run
- VCS `+lint=all` did not report width, signedness, latch or FSM warnings. This is a limit of the tool's checks, not proof that none exist.
- With default parameters `axi2apb_wrap` elaborates only `axi2apb`. `axi2apb_64_32` is parsed but not elaborated, so it is not fully linted. A second run with AXI_DATA_WIDTH=64 and APB_DATA_WIDTH=32 is planned.

## Conclusion
No functional DUT issue found by lint. Genuine DUT observations (unused PSLVERR, double semicolon) are documented and will be handled in the verification plan. The DUT was not modified.

## Manual RTL review (added after reading the FSM code)

| Finding | Where | Category | Disposition |
|---------|-------|----------|-------------|
| `NS` has no default assignment in the FSM `always_comb`. In the hold cases (IDLE with no request, WAIT_R_PREADY/WAIT_W_PREADY with PREADY low, SEND_B_RESP with BREADY low, DONE_SINGLE_RD with RREADY low) `NS` is not assigned, so a latch on `NS` would be inferred in synthesis. | axi2apb.sv, always_comb at line 331 | **Genuine DUT observation** (coding style). Not reported by VCS `+lint=all`. | Documented. DUT not modified. To be reported to the instructor. |

Simulation check (VCD of the DUT-only smoke run): `CS` and `NS` stay at 3'b000 (IDLE) from time 0, with no X values. A likely reason is that the case `default` branch assigns `NS = IDLE` at time 0 while `CS` is still unknown; this was not traced step by step.

Verification actions that follow from this finding:
- Assertion: the FSM state is never unknown (X/Z) after reset is released.
- Coverage: all five FSM states and their transitions, including the hold cases.
- Directed tests that keep PREADY, BREADY and RREADY low for several cycles to confirm the FSM holds its state correctly.
