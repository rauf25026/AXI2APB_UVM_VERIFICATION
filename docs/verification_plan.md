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
