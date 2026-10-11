# Verification Plan - AXI2APB Bridge

Status: in progress (Milestone 3). Sections are added step by step.
Every row traces one DUT behaviour to a stimulus, a checker and a coverage item.
`TBC` = to be confirmed by simulation (derived from the RTL, not yet observed).

## Naming
| Prefix | Meaning |
|--------|---------|
| VP-xxx-nn | Verification plan item |
| SB-... | Scoreboard check |
| A_... | SVA assertion |
| CG_... | Functional coverage group / point |
| ..._test | Planned UVM test |

## DUT behaviour used by this plan (axi2apb.sv, default parameters)
AXI signals below (ARVALID, AWVALID, WVALID, ...) are the signals after the AXI buffers, not the pins.

| State | Behaviour | Next state |
|-------|-----------|------------|
| IDLE | ARVALID has priority over AWVALID. A write needs AWVALID and WVALID together. The request starts in this same cycle (PENABLE=1). | PREADY=1: DONE_SINGLE_RD (read) or SEND_B_RESP (write). PREADY=0: WAIT_R_PREADY or WAIT_W_PREADY |
| WAIT_R_PREADY | PENABLE=1, read address held | PREADY=1: PRDATA saved in RDATA_Q, go to DONE_SINGLE_RD |
| WAIT_W_PREADY | PENABLE=1, PWRITE=1, write address and data held | PREADY=1: SEND_B_RESP |
| SEND_B_RESP | BVALID=1, BRESP=OKAY, BID/BUSER from AWID/AWUSER; AW and W buffers are popped when BREADY=1 | BREADY=1: IDLE |
| DONE_SINGLE_RD | RVALID=1, RLAST=1, RRESP=OKAY, RDATA=RDATA_Q; AR buffer is popped when RREADY=1 | RREADY=1: IDLE |

APB outputs: PSEL = 1 always; PENABLE = write_req or read_req; PWRITE = write_req; PADDR = address (0 when no request); PWDATA = WDATA.

Key observations:
- Only one transaction is active at a time (no APB pipelining).
- With PREADY=1 in the first cycle, the APB transfer takes one cycle.
- PSLVERR, WSTRB and WLAST are not used by the FSM. BRESP/RRESP are always OKAY.
- Reads have priority over writes, so continuous reads can delay a pending write.
- NS (next state) has no default assignment in the FSM (see docs/lint_summary.md).

## 1. Reset behaviour
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-RST-01 | Active-low asynchronous reset forces CS to IDLE and clears RDATA_Q | reset_smoke_test: reset at start of simulation | A_RST_IDLE: after reset the bridge is idle (see VP-RST-02). White-box check (bind or hierarchical reference) of CS == IDLE and RDATA_Q == 0 | CG_RESET: reset applied and released |
| VP-RST-02 | During and after reset: PENABLE=0, PWRITE=0, BVALID=0, RVALID=0. PSEL stays 1 (constant assign) | reset_smoke_test | A_RST_IDLE (outputs idle). A_PSEL_CONST: PSEL always 1 (documents the non-standard APB behaviour) | CG_RESET |
| VP-RST-03 | Reset in the middle of a transaction (for example while waiting for PREADY) returns the bridge to IDLE and a new transaction works afterwards. TBC | reset_mid_txn_test (extra test): reset while PREADY is held low, then run a normal write and read | A_RST_IDLE, scoreboard flushes expected transactions on reset | CG_RESET_STATE: reset applied in IDLE / write wait / read wait / response states |
| VP-RST-04 | FSM state is never X/Z after reset (NS has no default assignment) | reset_smoke_test, all tests | A_STATE_KNOWN: CS and NS never unknown after reset release | CG_FSM: all FSM states visited (code coverage fsm) |

## 2. AXI write-address (AW) handshake
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-AW-01 | AW is accepted into the AW buffer independently of W (AW can arrive before W) | aw_w_order_test (extra): AW first, W delayed; W first, AW delayed; both together | SB-WR: one APB write per AW/W pair, with correct address and data | CG_AW_W_ORDER: AW before W / W before AW / same cycle |
| VP-AW-02 | AW buffer has depth BUFF_DEPTH_SLAVE (4 by default). AWREADY goes low when the buffer is full. TBC | aw_fifo_depth_test (extra): send AW requests with no W data until AWREADY drops, then send W data | A_AW_STABLE (below), SB-WR | CG_AW_BUFFER: AWREADY low seen |
| VP-AW-03 | AWADDR[APB_ADDR_WIDTH-1:0] becomes PADDR. AWID and AWUSER come back as BID and BUSER | wr_no_wait_test, id_user_test | SB-WR: PADDR matches AWADDR. SB-RESP: BID/BUSER match AWID/AWUSER | CG_ADDR, CG_ID_USER |
| VP-AW-04 | AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWREGION and AWQOS are not used by the FSM. Document the observed effect, do not assume it | wr_no_wait_test with different values of these fields (single beat) | SB-WR: transfer is unchanged by these fields | CG_AW_CTRL: values of these fields seen |
| VP-AW-05 | AXI rule on the testbench side: once AWVALID is high, AWVALID and the AW payload stay stable until AWREADY | all tests | A_AW_STABLE | none |

## 3. AXI write-data (W) handshake
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-W-01 | W is accepted into the W buffer independently of AW | aw_w_order_test | SB-WR | CG_AW_W_ORDER |
| VP-W-02 | The bridge starts a write only when AW and W are both available. With only AW present, PENABLE stays 0 and PADDR stays 0. With only W present, nothing starts | aw_w_order_test: AW only for several cycles, then W; W only for several cycles, then AW | A_WR_NEEDS_AW_W: an APB write starts only after both an AW and a W have been accepted (counters). A_APB_IDLE_WITHOUT_REQ: no PENABLE while only one of AW/W is pending | CG_AW_W_ORDER |
| VP-W-03 | WDATA goes to PWDATA unchanged. WSTRB is ignored, and APB has no PSTRB | wstrb_wlast_test (extra): all-ones, partial and zero WSTRB | SB-WR: PWDATA == WDATA whatever WSTRB is. Observed behaviour is written in the final report | CG_WSTRB: all-ones / partial / zero. CG_DATA: zero, all-ones, alternating, walking, random |
| VP-W-04 | WLAST is not used by the FSM. Observe behaviour for a normal single beat (WLAST=1). WLAST=0 on a single beat is illegal AXI: optional documented experiment only | wstrb_wlast_test | SB-WR | CG_WLAST |
| VP-W-05 | AXI rule on the testbench side: WVALID, WDATA, WSTRB and WLAST stay stable until WREADY | all tests | A_W_STABLE | none |

## 4. Write conversion to APB
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-WR-01 | For each accepted AW + W the APB shows PSEL=1, PWRITE=1, PENABLE=1, PADDR=AWADDR, PWDATA=WDATA, and holds them until PREADY=1 | wr_no_wait_test, wr_wait_test | SB-WR (address, direction and data compare). A_APB_STABLE: control, address and data stay stable while PREADY is low | CG_TXN_TYPE: write seen |
| VP-WR-02 | PENABLE is high only while a request is active. PADDR is 0 when there is no request | all tests | A_APB_IDLE_WITHOUT_REQ. A_APB_CTRL_LEGAL: no PWRITE=1 without PENABLE | none |
| VP-WR-03 | Exactly one APB write per AXI single-beat write | wr_no_wait_test, b2b_wr_test | SB-WR: write counts match | CG_TXN_TYPE |
| VP-WR-04 | Address boundaries: 0x0, 0x4, 0xFFFFFFFC, and addresses with upper bits set (only the lower APB_ADDR_WIDTH bits are used) | wr_no_wait_test (directed addresses), constrained-random tests | SB-WR | CG_ADDR: low / mid / high / boundary bins |
| VP-WR-05 | Data patterns: zero, all-ones, alternating (0xAAAAAAAA, 0x55555555), walking-one, random | wr_no_wait_test (directed data), random tests | SB-WR | CG_DATA |
| VP-WR-06 | With PREADY high from the first request cycle, the APB transfer lasts exactly one cycle (PENABLE high for one cycle) | wr_no_wait_test | A_APB_NO_WAIT: PENABLE is high for one cycle when PREADY was already high. SB-WR | CG_WAIT: zero-wait write |

## Buffering note (from axi_single_slice.sv)
Every AXI channel passes through a FIFO (depth BUFF_DEPTH_SLAVE = 4, no fall-through): ready = FIFO not full, valid = FIFO not empty. Consequences used in the rows below:
- A handshake at the pins happens before the FSM sees the request (at least one cycle later).
- AWREADY, WREADY and ARREADY go low only when the matching FIFO is full.
- BREADY or RREADY low reaches the FSM only when the B or R FIFO is full. Until then the FIFO absorbs the responses. TBC (exact count to be observed).

## 5. APB PREADY wait states for writes
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-WW-01 | PREADY low in the first request cycle: FSM goes to WAIT_W_PREADY and holds PENABLE=1, PWRITE=1, PADDR and PWDATA until PREADY=1 | wr_wait_test: PREADY delay of 1, 2, 3, 5 and 10 cycles | A_APB_STABLE, SB-WR | CG_WAIT: write with 0 / 1 / 2-4 / 5+ wait cycles |
| VP-WW-02 | Wait cycles delay completion but do not change address or data | wr_wait_test with random address and data | SB-WR: compare address and data at the PREADY cycle, not only at the first cycle | CG_WAIT |
| VP-WW-03 | The B response is produced only after the APB write completes (PREADY=1) | wr_wait_test | A_BRESP_AFTER_APB: BVALID only after a write completion. SB-RESP | CG_WAIT |
| VP-WW-04 | Long wait (for example 50 cycles): the DUT has no timeout and keeps waiting | wr_wait_test (long case) | A_APB_STABLE. Testbench watchdog separates a slow slave from a DUT hang | CG_WAIT: 5+ bin |

## 6. AXI B-channel response and BREADY backpressure
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-B-01 | BVALID after the APB write completes. BRESP is always OKAY in this RTL | wr_no_wait_test, wr_wait_test | SB-RESP: BRESP == OKAY | CG_RESP: BRESP values seen |
| VP-B-02 | BID = AWID and BUSER = AWUSER of the same write | id_user_test | SB-RESP | CG_ID_USER |
| VP-B-03 | BVALID and the B payload stay stable until BREADY (AXI rule) | wr_bready_delay_test | A_B_STABLE | CG_BREADY: delay 0 / 1-3 / 4+ cycles |
| VP-B-04 | BREADY low: the B FIFO absorbs responses and the FSM stalls in SEND_B_RESP only when the FIFO is full. TBC | wr_bready_delay_test: back-to-back writes with BREADY held low for many cycles | SB-RESP: responses return in order, none lost, none duplicated. A_B_STABLE | CG_B_BUFFER_FULL: write issued while the B FIFO is full |
| VP-B-05 | Back-to-back writes return B responses in write order with the correct IDs | b2b_wr_test | SB-RESP (queue compare) | CG_B2B: back-to-back writes |

## 7. AXI read-address (AR) handshake
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-AR-01 | AR is accepted into the AR FIFO. ARREADY goes low only when the FIFO is full. TBC | rd_no_wait_test, b2b_rd_test (also many ARs while RREADY is held low) | SB-RD, A_AR_STABLE | CG_AR_BUFFER: ARREADY low seen |
| VP-AR-02 | ARADDR[APB_ADDR_WIDTH-1:0] becomes PADDR | rd_no_wait_test | SB-RD | CG_ADDR |
| VP-AR-03 | ARID and ARUSER come back as RID and RUSER | id_user_test | SB-RD | CG_ID_USER |
| VP-AR-04 | ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARREGION and ARQOS are not used by the FSM. Document the observed effect | rd_no_wait_test with different values of these fields (single beat) | SB-RD: transfer is unchanged | CG_AR_CTRL |
| VP-AR-05 | AXI rule on the testbench side: ARVALID and the AR payload stay stable until ARREADY | all tests | A_AR_STABLE | none |

## 8. Read conversion to APB
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-RD-01 | For each accepted AR the APB shows PSEL=1, PWRITE=0, PENABLE=1, PADDR=ARADDR and holds them until PREADY=1 | rd_no_wait_test, rd_wait_test | SB-RD (address and direction compare). A_APB_STABLE | CG_TXN_TYPE: read seen |
| VP-RD-02 | Exactly one APB read per AXI single-beat read. PWDATA is not checked on reads | rd_no_wait_test, b2b_rd_test | SB-RD: read counts match | CG_TXN_TYPE |
| VP-RD-03 | With PREADY high in the first cycle the APB read lasts one cycle and PRDATA is sampled in that cycle | rd_no_wait_test | A_APB_NO_WAIT, SB-RD | CG_WAIT: zero-wait read |
| VP-RD-04 | Address boundaries and read-data patterns (zero, all-ones, alternating, walking, random) | rd_no_wait_test, random tests | SB-RD | CG_ADDR, CG_DATA |

## 9. APB PREADY wait states for reads
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-RW-01 | PREADY low: FSM goes to WAIT_R_PREADY and holds the read control and address until PREADY=1 | rd_wait_test: PREADY delay of 1, 2, 3, 5 and 10 cycles | A_APB_STABLE, SB-RD | CG_WAIT: read with 0 / 1 / 2-4 / 5+ wait cycles |
| VP-RW-02 | PRDATA is captured only in the cycle where PREADY=1 (sample_RDATA = PREADY). PRDATA values while PREADY is low must be ignored | rd_wait_test: the APB slave drives different junk values on PRDATA while PREADY is low | SB-RD: RDATA == PRDATA of the PREADY cycle | CG_WAIT |
| VP-RW-03 | RDATA is held in RDATA_Q, so later changes on PRDATA do not change a pending response | rd_wait_test: change PRDATA after the transfer completes | A_R_STABLE: RDATA stable while RVALID is high and RREADY is low. SB-RD | none |
| VP-RW-04 | Long wait (for example 50 cycles): the bridge waits, no timeout | rd_wait_test (long case) | Testbench watchdog | CG_WAIT: 5+ bin |

## 10. PRDATA capture and AXI RDATA response
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-RR-01 | The PRDATA sampled in the PREADY cycle (RDATA_Q) is returned as RDATA with RVALID=1 | rd_no_wait_test, rd_wait_test | SB-RD: RDATA == PRDATA of the matching APB read | CG_DATA: zero, all-ones, alternating, walking, random |
| VP-RR-02 | RRESP is always OKAY in this RTL | all read tests | SB-RD, A_RESP_OKAY: RRESP and BRESP are always OKAY (flags it if the behaviour ever changes) | CG_RESP |
| VP-RR-03 | One AXI read returns exactly one R beat | rd_no_wait_test, b2b_rd_test | SB-RD: number of R beats == 1 per AR | CG_TXN_TYPE |

## 11. RVALID / RREADY backpressure and RLAST
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-RV-01 | RVALID and the R payload (RDATA, RID, RUSER, RRESP, RLAST) stay stable until RREADY (AXI rule) | rd_rready_delay_test | A_R_STABLE | CG_RREADY: delay 0 / 1-3 / 4+ cycles |
| VP-RV-02 | RLAST is 1 on every read response (single-read response of this RTL) | all read tests | A_R_LAST: every R handshake has RLAST=1 | CG_RLAST |
| VP-RV-03 | RREADY low: the R FIFO absorbs responses. The FSM stalls in DONE_SINGLE_RD and the AR entry is popped only when the response is accepted. TBC | rd_rready_delay_test: back-to-back reads with RREADY held low for many cycles | SB-RD: responses return in order, none lost, none duplicated. A_R_STABLE | CG_R_BUFFER_FULL: read issued while the R FIFO is full |

## 12. AXI ID and USER propagation
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-ID-01 | BID/BUSER = AWID/AWUSER and RID/RUSER = ARID/ARUSER of the same transaction | id_user_test | SB-RESP (write), SB-RD (read) | CG_ID_USER: zero, all-ones, walking-one and random values over the full ID and USER width (widths as instantiated in the testbench top), crossed with read/write |
| VP-ID-02 | The same ID used on consecutive transactions, and different IDs on consecutive transactions, do not mix up responses | id_user_test, b2b_rd_test, b2b_wr_test | SB-RESP, SB-RD | CG_ID_USER |

## 13. Simultaneous read and write request (priority)
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-PRI-01 | When an AR and an AW+W are both available while the FSM is in IDLE, the read is served first | rd_wr_priority_test: (a) AR and AW+W presented in the same cycle. (b) Keep the APB busy with PREADY low so both queue up in the FIFOs, then release | SB-ORDER: the APB read comes before the APB write. A_RD_PRIORITY (white-box): ARVALID and AWVALID both high in IDLE -> read chosen | CG_PRIORITY: same-cycle / queued-behind-busy-APB |
| VP-PRI-02 | The write is not lost: it executes after the read | rd_wr_priority_test | SB-WR: write completes with correct data | CG_PRIORITY |
| VP-PRI-03 | Continuous reads can delay a pending write (read priority). Document the behaviour, do not assume fairness | rd_wr_priority_test: a pending write with N consecutive reads (N = 1, 2, 4, 8) | SB-ORDER records the delay. The write must complete after the last read | CG_PRIORITY: write waiting behind 1 / 2-4 / 5+ reads |

## 14. Back-to-back and mixed traffic
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-B2B-01 | Back-to-back reads (more than the FIFO depth of 4): one APB read per AR, order preserved, no data mix-up | b2b_rd_test: 8 and more reads with zero idle cycles | SB-RD (queue compare) | CG_B2B: read followed by read |
| VP-B2B-02 | Back-to-back writes (more than the FIFO depth of 4) | b2b_wr_test | SB-WR, SB-RESP | CG_B2B: write followed by write |
| VP-B2B-03 | Mixed read/write traffic. AXI does not order reads against writes, so the scoreboard keeps separate read and write queues. Order is checked inside each direction only | mixed_rw_test | SB-RD, SB-WR (per-direction queues) | CG_B2B: read then write, write then read |

## 15. Different values, boundary addresses, parameter widths
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-VAL-01 | Address and data values over the full range: 0, all-ones, alternating, walking, random | all directed tests, random tests | SB-WR, SB-RD | CG_ADDR, CG_DATA |
| VP-VAL-02 | Unaligned addresses (AxADDR[1:0] != 0) pass through to PADDR unchanged. Document the behaviour | wr_no_wait_test, rd_no_wait_test with unaligned addresses | SB-WR, SB-RD | CG_ADDR: aligned / unaligned bins |
| VP-PAR-01 | When APB_ADDR_WIDTH is smaller than AXI4_ADDRESS_WIDTH, only the lower APB_ADDR_WIDTH bits reach PADDR. Needs a second parameter configuration | param_width_test (optional extra, second compile configuration) | SB-WR, SB-RD: expected PADDR = AxADDR truncated | CG_ADDR |
| VP-PAR-02 | 64-bit AXI data with 32-bit APB data uses the module axi2apb_64_32. The default configuration does not elaborate it (see docs/lint_summary.md). Analyse that module before planning checks. TBC | param_width_test (optional extra) | to be defined after the analysis | to be defined |

## 16. PSLVERR behaviour (as implemented by the supplied RTL)
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-ERR-01 | PSLVERR is not used by the FSM. BRESP and RRESP stay OKAY even when PSLVERR=1. This is the supplied RTL behaviour, not the AMBA expectation, and it is documented | pslverr_test: writes and reads with PSLVERR=1 and with PSLVERR=0 | SB-RESP, SB-RD expect OKAY whatever PSLVERR is. A_RESP_OKAY | CG_PSLVERR: PSLVERR high / low crossed with read / write and with wait states |
| VP-ERR-02 | PSLVERR high while PREADY is low, and PSLVERR high without a request, has no effect | pslverr_test | A_RESP_OKAY, SB checks unchanged | CG_PSLVERR |
| VP-ERR-03 | On a read with PSLVERR=1 the PRDATA of the PREADY cycle is still returned as RDATA | pslverr_test | SB-RD: RDATA == PRDATA | CG_PSLVERR |

## 17. Unsupported or not-implemented features (observe and document, do not assume)
| ID | Feature / RTL behaviour | Stimulus (test) | Checker | Coverage |
|----|-------------------------|-----------------|---------|----------|
| VP-UNS-01 | Write burst (AWLEN > 0). The FSM pops one W entry per write, so predicted: the remaining W beats stay in the W FIFO and pair with the next AW. Predicted from the RTL, TBC | burst_observe_test (extra, directed, documented): AWLEN=1 with 2 W beats, then a normal write | No pass/fail against AXI. The observed APB activity and B count are recorded in the final report | CG_BURST_LEN: AWLEN / ARLEN values seen |
| VP-UNS-02 | Read burst (ARLEN > 0). The FSM returns one R beat with RLAST=1, so an AXI master waiting for more beats would hang. TBC | burst_observe_test: ARLEN=1 | Observed behaviour recorded in the final report | CG_BURST_LEN |
| VP-UNS-03 | Narrow transfers (AxSIZE smaller than the data width), FIXED and WRAP burst types, AxLOCK, AxCACHE, AxPROT, AxQOS and AxREGION are not used by the FSM | wr_no_wait_test, rd_no_wait_test with these fields varied (single beat) | SB-WR, SB-RD: transfer unchanged | CG_AW_CTRL, CG_AR_CTRL |

## 18. Traceability summary

### 18.1 Required plan sections (project specification, Milestone 3) -> this plan
| Required section | Plan section |
|------------------|--------------|
| Reset behavior | 1 |
| AXI write-address handshake | 2 |
| AXI write-data handshake | 3 |
| Write conversion to APB (PADDR, PWRITE, PENABLE, PSEL, PWDATA) | 4 |
| APB PREADY low / wait states for writes | 5 |
| AXI B-channel response and BREADY backpressure | 6 |
| AXI read-address handshake | 7 |
| Read conversion to APB | 8 |
| APB PREADY low / wait states for reads | 9 |
| PRDATA capture and AXI RDATA response | 10 |
| RVALID / RREADY backpressure and RLAST | 11 |
| AXI ID and USER propagation | 12 |
| Simultaneous read/write priority | 13 |
| Back-to-back transactions | 14 |
| Different address / data / ID / USER values | 12, 15 |
| Boundary addresses and parameter widths | 15 |
| PSLVERR behaviour as implemented | 16 |
| Unsupported features such as burst | 17 |

Total plan items: 66. Items marked TBC (to be confirmed by simulation): 8 (VP-RST-03, VP-AW-02, VP-B-04, VP-AR-01, VP-RV-03, VP-PAR-02, VP-UNS-01, VP-UNS-02).

### 18.2 Tests -> plan items
Assertions run in every test, so rows that say "all tests" (VP-RST-04, VP-AW-05, VP-W-05, VP-WR-02, VP-AR-05, VP-RR-02, VP-RV-02, VP-VAL-01) are not repeated below.

The first 13 tests are the minimum directed tests of Milestone 8. The tests marked "extra" are added from the RTL analysis.

| Test | Plan items |
|------|------------|
| reset_smoke_test | VP-RST-01, VP-RST-02, VP-RST-04 |
| wr_no_wait_test | VP-AW-03, VP-AW-04, VP-WR-01, VP-WR-03 to VP-WR-06, VP-B-01, VP-VAL-01, VP-VAL-02, VP-UNS-03 |
| rd_no_wait_test | VP-AR-01, VP-AR-02, VP-AR-04, VP-RD-01 to VP-RD-04, VP-RR-01, VP-RR-03, VP-VAL-01, VP-VAL-02, VP-UNS-03 |
| wr_wait_test | VP-WR-01, VP-WW-01 to VP-WW-04, VP-B-01 |
| rd_wait_test | VP-RD-01, VP-RW-01 to VP-RW-04, VP-RR-01 |
| rd_rready_delay_test | VP-RV-01, VP-RV-03 |
| wr_bready_delay_test | VP-B-03, VP-B-04 |
| rd_wr_priority_test | VP-PRI-01 to VP-PRI-03 |
| b2b_rd_test | VP-AR-01, VP-RD-02, VP-RR-03, VP-ID-02, VP-B2B-01 |
| b2b_wr_test | VP-WR-03, VP-B-05, VP-ID-02, VP-B2B-02 |
| mixed_rw_test | VP-B2B-03 |
| id_user_test | VP-AW-03, VP-B-02, VP-AR-03, VP-ID-01, VP-ID-02 |
| pslverr_test | VP-ERR-01 to VP-ERR-03 |
| reset_mid_txn_test (extra) | VP-RST-03 |
| aw_w_order_test (extra) | VP-AW-01, VP-W-01, VP-W-02 |
| aw_fifo_depth_test (extra) | VP-AW-02 |
| wstrb_wlast_test (extra) | VP-W-03, VP-W-04 |
| burst_observe_test (extra) | VP-UNS-01, VP-UNS-02 |
| param_width_test (optional extra) | VP-PAR-01, VP-PAR-02 |
| random_rw_test (Milestone 9) | VP-VAL-01, VP-WR-04, VP-WR-05, VP-RD-04 and all checkers |

### 18.3 Assertions -> plan items
| Assertion | Rule | Plan items |
|-----------|------|------------|
| A_RST_IDLE | After reset the bridge is idle: PENABLE=0, PWRITE=0, BVALID=0, RVALID=0 | VP-RST-01, VP-RST-02, VP-RST-03 |
| A_PSEL_CONST | PSEL is always 1 (documents the non-standard APB behaviour) | VP-RST-02 |
| A_STATE_KNOWN | CS and NS never X/Z after reset release | VP-RST-04 |
| A_AW_STABLE | AWVALID and the AW payload stay stable until AWREADY | VP-AW-02, VP-AW-05 |
| A_W_STABLE | WVALID and the W payload stay stable until WREADY | VP-W-05 |
| A_AR_STABLE | ARVALID and the AR payload stay stable until ARREADY | VP-AR-01, VP-AR-05 |
| A_WR_NEEDS_AW_W | An APB write starts only after both an AW and a W were accepted | VP-W-02 |
| A_APB_IDLE_WITHOUT_REQ | No PENABLE while only one of AW/W is pending or when idle | VP-W-02, VP-WR-02 |
| A_APB_STABLE | APB control, address and data stay stable while PREADY is low | VP-WR-01, VP-WW-01, VP-WW-04, VP-RD-01, VP-RW-01 |
| A_APB_CTRL_LEGAL | No illegal APB control combination (for example PWRITE=1 without PENABLE) | VP-WR-02 |
| A_APB_NO_WAIT | With PREADY high in the first cycle PENABLE lasts one cycle | VP-WR-06, VP-RD-03 |
| A_BRESP_AFTER_APB | BVALID only after an APB write completion | VP-WW-03 |
| A_B_STABLE | BVALID and the B payload stay stable until BREADY | VP-B-03, VP-B-04 |
| A_R_STABLE | RVALID and the R payload stay stable until RREADY | VP-RW-03, VP-RV-01, VP-RV-03 |
| A_R_LAST | Every R handshake has RLAST=1 | VP-RV-02 |
| A_RESP_OKAY | BRESP and RRESP are always OKAY | VP-RR-02, VP-ERR-01, VP-ERR-02 |
| A_RD_PRIORITY | ARVALID and AWVALID both high in IDLE: the read is chosen (white-box) | VP-PRI-01 |

### 18.4 Scoreboard checks -> plan items
| Check | What it compares | Plan items |
|-------|------------------|------------|
| SB-WR | AXI write -> predicted APB write: address, PWRITE=1, PWDATA, one APB write per AXI write | VP-AW-01 to VP-AW-04, VP-W-01, VP-W-03, VP-W-04, VP-WR-01, VP-WR-03 to VP-WR-05, VP-WW-01, VP-WW-02, VP-PRI-02, VP-B2B-02, VP-B2B-03, VP-VAL-01, VP-VAL-02, VP-PAR-01, VP-UNS-03 |
| SB-RD | AXI read -> predicted APB read address; PRDATA of the PREADY cycle returned as RDATA; RID/RUSER; one R beat | VP-AR-01 to VP-AR-04, VP-RD-01 to VP-RD-04, VP-RR-01 to VP-RR-03, VP-RV-03, VP-RW-01 to VP-RW-03, VP-ID-01, VP-ID-02, VP-B2B-01, VP-B2B-03, VP-VAL-01, VP-VAL-02, VP-ERR-03, VP-UNS-03 |
| SB-RESP | Write response: BRESP == OKAY, BID/BUSER, order, none lost or duplicated | VP-B-01, VP-B-02, VP-B-04, VP-B-05, VP-WW-03, VP-ID-01, VP-ID-02, VP-ERR-01 |
| SB-ORDER | Order of APB read and APB write when both are pending (read priority) | VP-PRI-01, VP-PRI-03 |

Read and write queues are kept separate, because AXI does not order reads against writes.

### 18.5 Functional coverage -> plan items
| Coverage | Content | Plan items |
|----------|---------|------------|
| CG_RESET, CG_RESET_STATE | Reset applied and released; reset in each FSM state | VP-RST-01 to VP-RST-03 |
| CG_FSM | All FSM states and transitions (VCS fsm code coverage) | VP-RST-04 |
| CG_TXN_TYPE | Read / write | VP-WR-01, VP-WR-03, VP-RD-01, VP-RD-02, VP-RR-03 |
| CG_ADDR | Low / mid / high / boundary, aligned / unaligned | VP-AW-03, VP-AR-02, VP-WR-04, VP-RD-04, VP-VAL-01, VP-VAL-02, VP-PAR-01 |
| CG_DATA | Zero, all-ones, alternating, walking, random | VP-W-03, VP-WR-05, VP-RD-04, VP-RR-01, VP-VAL-01 |
| CG_ID_USER | ID and USER values, crossed with read / write | VP-AW-03, VP-B-02, VP-AR-03, VP-ID-01, VP-ID-02 |
| CG_WAIT | PREADY wait cycles: 0 / 1 / 2-4 / 5+, for write and read | VP-WR-06, VP-WW-01 to VP-WW-04, VP-RD-03, VP-RW-01 to VP-RW-04 |
| CG_BREADY, CG_RREADY | Backpressure delay 0 / 1-3 / 4+ | VP-B-03, VP-RV-01 |
| CG_B_BUFFER_FULL, CG_R_BUFFER_FULL, CG_AW_BUFFER, CG_AR_BUFFER | FIFO full conditions | VP-B-04, VP-RV-03, VP-AW-02, VP-AR-01 |
| CG_B2B | Back-to-back: read-read, write-write, read-write, write-read | VP-B-05, VP-B2B-01 to VP-B2B-03 |
| CG_PRIORITY | Same-cycle and queued read/write, write behind 1 / 2-4 / 5+ reads | VP-PRI-01 to VP-PRI-03 |
| CG_AW_W_ORDER | AW before W / W before AW / same cycle | VP-AW-01, VP-W-01, VP-W-02 |
| CG_AW_CTRL, CG_AR_CTRL, CG_WSTRB, CG_WLAST, CG_BURST_LEN | Values of the fields the FSM does not use | VP-AW-04, VP-AR-04, VP-W-03, VP-W-04, VP-UNS-01 to VP-UNS-03 |
| CG_RESP, CG_RLAST | BRESP / RRESP values, RLAST | VP-B-01, VP-RR-02, VP-RV-02 |
| CG_PSLVERR | PSLVERR high / low, crossed with read / write and wait states | VP-ERR-01 to VP-ERR-03 |
| CG_CROSS | Transaction type x wait bin x backpressure bin x response (cross required by the project specification) | VP-WW-01, VP-RW-01, VP-B-03, VP-RV-01, VP-ERR-01 |
