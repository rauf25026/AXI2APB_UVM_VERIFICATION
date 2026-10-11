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

## 2026-10-11 (update - Milestone 3)
- **Work completed:** DUT analysis from the RTL (FSM, APB outputs, AXI buffers) and verification plan with 66 items (sections 1 to 17) plus traceability summary (section 18): tests, assertions, scoreboard checks and coverage mapped to plan items. Manual RTL review finding added to the lint summary (NS has no default assignment in the FSM).
- **Tests executed:** DUT-only smoke run (VCD checked for CS/NS values).
- **Pass/fail result:** No failures. 8 plan items are marked TBC for confirmation in simulation.
- **Coverage/lint status:** Lint done (docs/lint_summary.md). Functional coverage planned, not implemented yet.
- **Issues encountered:** The assumption that CS goes X after reset was not confirmed in the smoke run. Documented in the lint summary.
- **Next step:** Milestone 4/5 - UVM environment and agents (AXI master agent first).
