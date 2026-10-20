# Final Verification Report - AXI2APB Bridge



## 1. Summary
A dual-agent UVM environment (AXI master agent, APB slave agent, scoreboard, SVA checker, functional coverage)
was built for the supplied AXI4-to-APB bridge and run with VCS L-2016.06 (UVM 1.1d). The DUT was not modified.
8 tests were run with 3 seeds each: **24 of 24 runs passed**, with no UVM errors, scoreboard mismatches or assertion failures.

## 2. DUT and what was verified
Single outstanding transaction, FSM with IDLE, WAIT_W_PREADY, WAIT_R_PREADY, SEND_B_RESP and DONE_SINGLE_RD, a FIFO (depth 4) on every AXI channel.
Details: `docs/verification_plan.md` (66 plan items), `docs/lint_summary.md`.

## 3. Environment
- AXI master agent: sequence item, sequencer, driver (AW+W together, then B; AR then R), monitor.
- APB slave agent: reactive driver with a memory model (configurable extra wait cycles and PSLVERR rate), monitor.
- Scoreboard: AXI write against APB write (address, data), AXI read against APB read (address, PRDATA to RDATA), BRESP/RRESP, BID/RID, one read beat, left-over APB transfers. Separate read and write queues.
- Assertions (`assertions/axi2apb_checker.sv`): 11 SVA assertions (APB control stable while PREADY is low, PWDATA stable, PSEL always 1, BRESP/RRESP OKAY, RLAST, VALID/READY stability on AW, W, AR, B and R).
- Functional coverage (`uvm/axi2apb_coverage.sv`): read/write, ID, write-data patterns, APB direction, wait cycles, PSLVERR, address ranges, and crosses of direction x wait x PSLVERR.

## 4. Checker validation (mutation check)
The scoreboard was fed deliberately wrong data (`scripts/mutation_check.sh`, details in `results/scoreboard_mutation.md`): all 6 injected faults were caught.
One assertion (A_RESP_OKAY_B) was reversed on purpose and failed as expected (3 errors), then restored.

## 5. Results
### 5.1 Regression (scripts/regression.sh, 8 tests x 3 seeds, raw output in results/regression_summary.txt)
| Test | Runs passed | Matched (seed 1 / 2 / 3) | Functional coverage AXI | Functional coverage APB |
|------|-------------|--------------------------|-------------------------|-------------------------|
| bringup_test | 3 / 3 | W3 R3 (all seeds) | 63.9% | 43.1% to 52.8% |
| wr_wait_test | 3 / 3 | W10 (all seeds) | 47.2% | 40.3% |
| rd_wait_test | 3 / 3 | R10 (all seeds) | 38.9% to 50.0% | 40.3% |
| b2b_wr_test | 3 / 3 | W20 (all seeds) | 47.2% to 58.3% | 40.3% |
| b2b_rd_test | 3 / 3 | R20 (all seeds) | 38.9% to 50.0% | 40.3% |
| mixed_rw_test | 3 / 3 | W12 R18 / W15 R15 / W16 R14 | 63.9% | 56.9% |
| pslverr_test | 3 / 3 | W12 R18 / W15 R15 / W16 R14 | 63.9% | 70.8% |
| random_wide_test | 3 / 3 | W32 R28 / W29 R31 / W28 R32 | 88.9% to 100% | 97.2% to 98.6% |

Each test is narrow, so its own coverage is partial. The widest test (random_wide_test) reaches 88.9% to 100% (AXI) and 97.2% to 98.6% (APB).
The functional coverage values are per simulation run, not merged. The remaining uncovered bins were not analysed.

### 5.2 Code coverage
(VCS urg, all 24 regression runs merged; line, cond, fsm, toggle, branch)

```
Dashboard

Date: Tue Oct 20 11:59:50 2026

User: unknown

Version: L-2016.06
Command line: urg -full64 -dir ./out/build/simv.vdb -metric line+cond+fsm+tgl+branch -format both -report ./out/code_coverage_report 

Number of tests: 25

-------------------------------------------------------------------------------
Total Coverage Summary 
SCORE  LINE   COND   TOGGLE FSM    BRANCH 
 71.55  83.58  47.27  87.29  60.00  79.59 


-------------------------------------------------------------------------------
Hierarchical coverage data for top-level instances 
SCORE  LINE   COND   TOGGLE FSM    BRANCH NAME   
 71.55  83.58  47.27  87.29  60.00  79.59 tb_top 


-------------------------------------------------------------------------------
Total Module Definition Coverage Summary 
SCORE  LINE   COND   TOGGLE FSM    BRANCH 
 73.39  87.74  54.55  88.20  60.00  76.47 

```

The code coverage of the full hierarchy was not analysed or closed (uncovered lines and branches were not reviewed).

## 6. Findings about the supplied RTL
1. **PSLVERR is ignored.** With PSLVERR high on 15 of 30 APB transfers (`pslverr_test`), BRESP and RRESP stayed OKAY and read data was still returned. This matches the lint finding (unused input).
2. **FSM next-state has no default assignment** (`axi2apb.sv`); a latch would be inferred in synthesis. Simulation behaves correctly. Reported in `docs/lint_summary.md`.
3. **Non-standard APB:** PSEL is always 1 and PENABLE rises in the first request cycle (no setup phase). The APB slave therefore inserts at least one wait cycle.
4. Reads have priority over writes; WSTRB and WLAST are not used.

## 7. Limitations and not done
- The AXI driver has no VALID/READY delays and no BREADY/RREADY backpressure. Transactions are issued one at a time, so the FIFOs never fill (plan items VP-AW-02, VP-B-04, VP-AR-01, VP-RV-03 are not exercised and stay TBC).
- Not done: read/write priority test, reset in the middle of a transaction, burst observation, 64-bit data / parameter-width tests, dedicated ID and USER tests (IDs are random in all tests; BUSER/RUSER are not checked).
- Implemented: 11 assertions (17 were planned). Implemented tests are named differently from the plan; they cover plan sections 4 to 9, 14 (partly), 15 (VP-VAL-01) and 16.
- The monitors were validated through logs and the mutation check, not independently.
- Coverage closure was not completed.

## 8. How to reproduce



sed -i 's#| 6 - Scoreboard and reference model | In progress.*#| 6 - Scoreboard and reference model | Done: AXI vs APB checks, mutation check (6 of 6 faults caught) |#' README.md
sed -i 's#| 7 - Assertions and functional coverage | Not started |#| 7 - Assertions and functional coverage | Done: 11 SVA assertions, covergroups (random_wide_test: 88.9-100% AXI, 97.2-98.6% APB) |#' README.md
sed -i 's#| 8 to 10 - Directed and random tests, regression | Only bringup_test so far |#| 8 to 10 - Tests and regression | 8 tests x 3 seeds: 24 of 24 passed. Coverage closure not completed (see docs/final_report.md) |#' README.md
grep -n "^| [0-9]" README.md
cat >> docs/progress.md <<'EOF'

## ENTRY_DATE (summary of the work since the previous entry; commit dates are in `git log`)
- **Work completed:** Directed and random tests (wr_wait, rd_wait, b2b_wr, b2b_rd, mixed_rw, pslverr, random_wide), 11 SVA assertions, functional coverage, regression script (8 tests x 3 seeds), code coverage report, final report.
- **Tests executed:** Regression with 3 seeds.
- **Pass/fail result:** 24 of 24 runs passed. Assertion check: A_RESP_OKAY_B reversed on purpose failed as expected, then restored.
- **Coverage/lint status:** Functional coverage in random_wide_test: AXI 88.9-100%, APB 97.2-98.6%. Code coverage in docs/final_report.md.
- **Issues encountered:** `small` and `large` are reserved SystemVerilog words and cannot be bin names; functional coverage showed 0.0% until `option.per_instance = 1` was set; one VCS license failure (fixed with +vcs+lic+wait).
- **Next step:** Coverage closure, read/write priority and backpressure tests, if time allows.
