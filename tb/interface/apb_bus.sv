// -----------------------------------------------------------------------------
// APB_BUS : APB interface (name/modports match what axi2apb_wrap.sv expects)
//   - DUT port type  : APB_BUS.Master  (the bridge is the APB master)
//   - Signal names   : paddr, pwdata, pwrite, psel, penable, prdata, pready,
//                      pslverr (taken from axi2apb_wrap.sv)
//   - TB provides the APB slave/responder side
//   - NOTE: DUT drives PSEL as a single bit and has no PPROT/PSTRB.
// -----------------------------------------------------------------------------
`ifndef APB_BUS_SV
`define APB_BUS_SV

interface APB_BUS #(
    parameter int unsigned APB_ADDR_WIDTH = 32,
    parameter int unsigned APB_DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);

    logic [APB_ADDR_WIDTH-1:0] paddr;
    logic [APB_DATA_WIDTH-1:0] pwdata;
    logic                      pwrite;
    logic                      psel;
    logic                      penable;
    logic [APB_DATA_WIDTH-1:0] prdata;
    logic                      pready;
    logic                      pslverr;

    // ---- DUT-facing modports (.Master is fixed by axi2apb_wrap.sv) ----
    modport Master (
        output paddr, pwdata, pwrite, psel, penable,
        input  prdata, pready, pslverr
    );

    modport Slave (
        input  paddr, pwdata, pwrite, psel, penable,
        output prdata, pready, pslverr
    );

    // ---- Clocking blocks (UVM side) ----
    // drv_cb : APB slave/responder driver (drives prdata/pready/pslverr)
    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        input  paddr, pwdata, pwrite, psel, penable;
        output prdata, pready, pslverr;
    endclocking

    // mon_cb : passive monitor
    clocking mon_cb @(posedge clk);
        default input #1step;
        input paddr, pwdata, pwrite, psel, penable, prdata, pready, pslverr;
    endclocking

    modport DRIVER  (clocking drv_cb, input clk, input rst_n);
    modport MONITOR (clocking mon_cb, input clk, input rst_n);

endinterface : APB_BUS

`endif // APB_BUS_SV
