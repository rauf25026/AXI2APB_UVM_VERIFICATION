// -----------------------------------------------------------------------------
// Minimal DUT-only smoke top (no UVM). Only checks that RTL + interfaces
// compile, elaborate and run through reset. Default parameters, 32/32 bridge.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module dut_smoke_top;

    localparam int unsigned AXI_ADDR_WIDTH = 32;
    localparam int unsigned AXI_DATA_WIDTH = 32;
    localparam int unsigned AXI_ID_WIDTH   = 6;
    localparam int unsigned AXI_USER_WIDTH = 6;
    localparam int unsigned APB_ADDR_WIDTH = 32;
    localparam int unsigned APB_DATA_WIDTH = 32;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    always #5 clk = ~clk;   // 100 MHz

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_if (.clk(clk), .rst_n(rst_n));

    APB_BUS #(
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .APB_DATA_WIDTH ( APB_DATA_WIDTH )
    ) apb_if (.clk(clk), .rst_n(rst_n));

    axi2apb_wrap #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .APB_DATA_WIDTH ( APB_DATA_WIDTH )
    ) dut (
        .clk_i      ( clk     ),
        .rst_ni     ( rst_n   ),
        .test_en_i  ( 1'b0    ),
        .axi_slave  ( axi_if  ),
        .apb_master ( apb_if  )
    );

    // Waveform dump (make gui ke liye dump.vcd chahiye)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, dut_smoke_top);
    end

    // Idle inputs (smoke only: no traffic)
    initial begin
        axi_if.aw_valid = 0; axi_if.w_valid = 0; axi_if.b_ready = 0;
        axi_if.ar_valid = 0; axi_if.r_ready = 0;
        axi_if.aw_id = '0; axi_if.aw_addr = '0; axi_if.aw_len = '0; axi_if.aw_size = '0;
        axi_if.aw_burst = '0; axi_if.aw_lock = 0; axi_if.aw_cache = '0; axi_if.aw_prot = '0;
        axi_if.aw_region = '0; axi_if.aw_user = '0; axi_if.aw_qos = '0;
        axi_if.w_data = '0; axi_if.w_strb = '0; axi_if.w_last = 0; axi_if.w_user = '0;
        axi_if.ar_id = '0; axi_if.ar_addr = '0; axi_if.ar_len = '0; axi_if.ar_size = '0;
        axi_if.ar_burst = '0; axi_if.ar_lock = 0; axi_if.ar_cache = '0; axi_if.ar_prot = '0;
        axi_if.ar_region = '0; axi_if.ar_user = '0; axi_if.ar_qos = '0;
        apb_if.prdata = '0; apb_if.pready = 1'b1; apb_if.pslverr = 1'b0;

        repeat (5)  @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);
        $display("[SMOKE] DUT compiled, elaborated and came out of reset. PASS");
        $finish;
    end

endmodule
