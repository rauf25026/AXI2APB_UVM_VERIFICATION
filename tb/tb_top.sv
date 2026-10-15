`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi2apb_pkg::*;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    always #5 clk = ~clk;                        // 100 MHz

    initial begin                                // 10 clock reset, phir chhod do
        repeat (10) @(posedge clk);
        rst_n <= 1'b1;
    end

    // Asli interfaces (hardware wali dunya)
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_W ),
        .AXI_DATA_WIDTH ( AXI_DATA_W ),
        .AXI_ID_WIDTH   ( AXI_ID_W   ),
        .AXI_USER_WIDTH ( AXI_USER_W )
    ) axi_if (.clk(clk), .rst_n(rst_n));

    APB_BUS #(
        .APB_ADDR_WIDTH ( APB_ADDR_W ),
        .APB_DATA_WIDTH ( APB_DATA_W )
    ) apb_if (.clk(clk), .rst_n(rst_n));

    // DUT
    axi2apb_wrap #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_W ),
        .AXI_DATA_WIDTH ( AXI_DATA_W ),
        .AXI_USER_WIDTH ( AXI_USER_W ),
        .AXI_ID_WIDTH   ( AXI_ID_W   ),
        .APB_ADDR_WIDTH ( APB_ADDR_W ),
        .APB_DATA_WIDTH ( APB_DATA_W )
    ) dut (
        .clk_i      ( clk    ),
        .rst_ni     ( rst_n  ),
        .test_en_i  ( 1'b0   ),
        .axi_slave  ( axi_if ),
        .apb_master ( apb_if )
    );

    // Interfaces ko config_db (notice board) par rakho, phir test shuru karo
    initial begin
        uvm_config_db#(axi_vif_t)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(apb_vif_t)::set(null, "*", "apb_vif", apb_if);
        run_test();                              // test ka naam +UVM_TESTNAME se aata hai
    end

    // Waveform (make gui ke liye)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

    // Global watchdog: simulation latak jaye to khud khatam
    initial begin
        #1ms;
        $display("[TB] GLOBAL TIMEOUT - TEST FAILED");
        $finish;
    end

endmodule
