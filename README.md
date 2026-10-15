# AXI2APB UVM Verification

## Objective
Verify the AXI4-to-APB bridge (`axi2apb`) with a dual-agent UVM environment
(AXI master agent + APB slave agent), scoreboard / reference model, assertions,
functional coverage, directed and constrained-random tests.

## DUT source
AXI2APB bridge RTL from the PULP platform (ETH Zurich / University of Bologna),
used exactly as supplied for the training exercise. **The DUT is not modified.**

## Tools and environment
| Item | Version |
|------|---------|
| Simulator | Synopsys VCS L-2016.06_Full64 |
| Methodology | UVM (VCS `-ntb_opts uvm`) |
| OS | Ubuntu 18.04 (Docker container) |
| Git | 2.17.1 |

## Repository structure
```
rtl/         DUT and required dependent RTL (rtl/axi2apb_bridge)
tb/          top-level testbench and interfaces (tb/interface: AXI_BUS, APB_BUS)
uvm/         agents, env, config, scoreboard, coverage
sequences/   AXI / APB / virtual sequences
tests/       UVM tests
assertions/  SVA / checkers
coverage/    coverage files
scripts/     Makefile, build.flist, cov.cfg (compile, simulation, regression)
docs/        specification, verification plan, progress log, final report
logs/        selected human-readable logs only
results/     selected reports / results
```

## How to run
```
cd scripts
make run              # compile + run bringup_test (UVM)
make clean
```
Compile details and the file list: [docs/milestone1_compile.md](docs/milestone1_compile.md)

## Current status
| Milestone | Status |
|-----------|--------|
| 0 - Repository and GitHub setup | Done |
| 1 - Compile the DUT | Done (clean compile/elaboration, DUT-only smoke top passes reset) |
| 2 - RTL linting | Done, 36 messages classified (docs/lint_summary.md) |
| 3 - DUT analysis and verification plan | Done (docs/verification_plan.md, 66 items) |
| 4 and 5 - UVM environment and agents | Done: AXI master agent, APB slave agent, env, tb_top (single-beat traffic) |
| 6 - Scoreboard and reference model | In progress: write, read and response checks work; mutation check pending |
| 7 - Assertions and functional coverage | Not started |
| 8 to 10 - Directed and random tests, regression | Only bringup_test so far |

Daily progress: [docs/progress.md](docs/progress.md)
