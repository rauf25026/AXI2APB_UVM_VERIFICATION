# Scoreboard mutation check

## Idea
The scoreboard was fed deliberately wrong data (`+MUT=<n>`) to prove that its checks really fail when
something is wrong. The DUT is not touched; the faults are injected at the scoreboard input.
`MUT=0` changes nothing.

Run (after `make compile`): `bash scripts/mutation_check.sh`

## Result (test: bringup_test, 3 writes + 3 read-backs)
| MUT | Fault injected | Check that must catch it | Result | UVM_ERROR |
|-----|----------------|--------------------------|--------|-----------|
| 0 | none | | PASS | 0 |
| 1 | bit 2 of every APB address flipped | SB_WR / SB_RD address | FAIL | 6 |
| 2 | bit 0 of APB write data flipped | SB_WR PWDATA | FAIL | 3 |
| 3 | bit 0 of APB read data flipped | SB_RD RDATA | FAIL | 3 |
| 4 | second APB write removed | SB_WR "no APB write seen" | FAIL | 1 |
| 5 | BRESP changed to SLVERR | SB_RESP BRESP | FAIL | 3 |
| 6 | RID changed | SB_RD RID | FAIL | 3 |

Example (MUT=1): `PADDR mismatch: AXI addr=0x00001000 APB addr=0x00001004`

## Why MUT=4 gives one error
The test runs one transaction at a time, so each AXI write finds its own APB write; only the write
whose APB item was removed fails.

## Limits
- This tests the scoreboard logic. It does not prove that the monitors sample the pins correctly.
- Only one test was used.
