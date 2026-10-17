# Progress Log

## 2026-10-11
- **Work completed:**
  - Repository structure created as per project specification (section 18), README.md and .gitignore added.
  - DUT dependency analysis; file list prepared in dependency-safe order.
  - AXI_BUS / APB_BUS interfaces written from the wrapper ports.
  - Makefile / build.flist / cov.cfg for VCS; DUT-only smoke top.
- **Tests executed:** DUT-only smoke top (reset, idle inputs).
- **Pass/fail result:** PASS (compile, elaboration and reset run clean).
- **Coverage/lint status:** Coverage collection enabled in the compile flow; lint not run yet.
- **Issues encountered:** None in the DUT compile.
- **Next step:** Milestone 2 - RTL lint on the same file list.

## 2026-10-11 (update - Milestone 2)
- **Work completed:** RTL lint with VCS `+lint=all` on the compile file list; 36 messages reviewed and classified (docs/lint_summary.md).
- **Tests executed:** Lint run (scripts/lint.sh).
- **Pass/fail result:** No errors. 36 messages, all dispositioned.
- **Coverage/lint status:** Lint done. Key finding: PSLVERR is unused by the DUT (as in the spec).
- **Issues encountered:** `-lint=all` is not accepted by this VCS version; `+lint=all` is the correct option.
- **Next step:** Milestone 3 - DUT analysis and verification plan.

## 2026-10-12 (Milestone 3 completion)
- **Work completed:** DUT analysis from the RTL (FSM, APB outputs, AXI buffers) and verification plan with 66 items (sections 1 to 17, committed 2026-10-11) plus traceability summary (section 18, committed 2026-10-12): tests, assertions, scoreboard checks and coverage mapped to plan items. Manual RTL review finding added to the lint summary (NS has no default assignment in the FSM).
- **Tests executed:** DUT-only smoke run (VCD checked for CS/NS values).
- **Pass/fail result:** No failures. 8 plan items are marked TBC for confirmation in simulation.
- **Coverage/lint status:** Lint done (docs/lint_summary.md). Functional coverage planned, not implemented yet.
- **Issues encountered:** The assumption that CS goes X after reset was not confirmed in the smoke run. Documented in the lint summary.
- **Next step:** Milestone 4/5 - UVM environment and agents (AXI master agent first).

## 2026-10-13 (entry written afterwards from the commit history)
- **Work completed:** UVM package `axi2apb_pkg` and AXI sequence item (single beat by default, constraints for the DUT's supported behaviour). AXI sequencer and AXI master driver (AW and W together, then B; AR then R; handshake timeouts). AXI monitor (builds complete read and write transactions and sends them to an analysis port) and AXI agent.
- **Tests executed:** VCS compile of the UVM package. No simulation yet.
- **Pass/fail result:** Compile clean (no `Error` lines).
- **Coverage/lint status:** Not started.
- **Issues encountered:** None found on this day (see 2026-10-14).
- **Next step:** APB agent.

## 2026-10-14 (entry written afterwards from the commit history)
- **Work completed:** APB sequence item, APB agent config object and reactive APB slave driver with a small memory model (configurable extra wait cycles and PSLVERR rate). Fixed the package: the AXI monitor and AXI agent were committed on 2026-10-13 but were not included in the package, so VCS had not compiled them.
- **Tests executed:** VCS compile of the UVM package.
- **Pass/fail result:** Compile clean with all AXI classes now actually included.
- **Coverage/lint status:** Not started.
- **Issues encountered:** A clean compile does not prove a file is correct if the file is not in the build. From now on the `include` lines of the package are checked before each compile.
- **Next step:** APB monitor and agent.

## 2026-10-15 (entry written afterwards from the commit history)
- **Work completed:** APB monitor (a transfer is complete when PSEL, PENABLE and PREADY are all high; counts wait cycles) and APB agent (driver and monitor, no sequencer because the driver is reactive).
- **Tests executed:** VCS compile of the UVM package.
- **Pass/fail result:** Compile clean.
- **Coverage/lint status:** Not started.
- **Issues encountered:** None.
- **Next step:** Env, sequence, test and `tb_top`; first run with real traffic.

## 2026-10-16
- **Work completed:** UVM env (AXI agent, APB agent), AXI write-then-read-back sequence, `bringup_test`, UVM `tb_top`; the compile flow now uses `tb_top` instead of the smoke top. Scoreboard with write, read and response checks (SB-WR, SB-RD, SB-RESP) and separate read and write queues, connected to both monitors in the env.
- **Tests executed:** `bringup_test`: 3 AXI writes, each followed by a read-back of the same address, through the DUT.
- **Pass/fail result:** PASS. Scoreboard: writes matched=3, reads matched=3, errors=0. UVM_ERROR=0, UVM_FATAL=0. APB wait cycles seen: 1, 3, 2, 1. The APB slave inserts at least one wait cycle because the DUT raises PENABLE in the first request cycle.
- **Coverage/lint status:** Code coverage collection is enabled (line, cond, fsm, tgl, branch) but no report has been analysed. Functional coverage and assertions are not implemented yet.
- **Issues encountered:** Before the scoreboard, the test passed only because of a check inside the sequence, which sees the AXI side only. The scoreboard adds the APB-side check. The scoreboard has not yet been shown to catch a real error (a mutation check is planned).
- **Next step:** Mutation check of the scoreboard, then the directed tests from the verification plan, assertions and functional coverage.

## 2026-10-18 (scoreboard mutation check)
- **Work completed:** Mutation hooks (+MUT=1..6) in the scoreboard and `scripts/mutation_check.sh`; results saved in `results/scoreboard_mutation.md`.
- **Tests executed:** `bringup_test` with MUT=0 to 6.
- **Pass/fail result:** MUT=0 passes with 0 errors; MUT=1 to 6 all fail with the expected number of errors (6, 3, 3, 1, 3, 3). Every injected fault was caught.
- **Coverage/lint status:** Unchanged.
- **Issues encountered:** None.
- **Next step:** A few simple directed tests (APB wait states), then assertions and coverage.
