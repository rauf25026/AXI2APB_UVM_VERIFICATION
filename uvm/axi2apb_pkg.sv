// axi2apb_pkg : saari UVM classes is package mein aati hain
package axi2apb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // DUT ki widths (axi2apb_wrap ke defaults). Sirf yahan badlein, baaqi sab khud badalta hai
    parameter int AXI_ADDR_W   = 32;
    parameter int AXI_DATA_W   = 32;
    parameter int AXI_ID_W     = 6;
    parameter int AXI_USER_W   = 6;
    parameter int APB_ADDR_W   = 32;
    parameter int APB_DATA_W   = 32;
    parameter int AXI_STRB_W   = AXI_DATA_W/8;
    parameter int AXI_SIZE_MAX = 2;      // log2(AXI_DATA_W/8) for 32-bit data

    // Virtual interface ka type: class isi se asli AXI_BUS interface tak pohanchti hai
    typedef virtual AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_W ),
        .AXI_DATA_WIDTH ( AXI_DATA_W ),
        .AXI_ID_WIDTH   ( AXI_ID_W   ),
        .AXI_USER_WIDTH ( AXI_USER_W )
    ) axi_vif_t;

    `include "axi_agent/axi_item.sv"
    `include "axi_agent/axi_sequencer.sv"
    `include "axi_agent/axi_driver.sv"

endpackage : axi2apb_pkg
