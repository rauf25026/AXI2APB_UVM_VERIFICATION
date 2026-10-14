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

    // Virtual interface ke types: class inhi se asli interfaces tak pohanchti hai
    typedef virtual AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_W ),
        .AXI_DATA_WIDTH ( AXI_DATA_W ),
        .AXI_ID_WIDTH   ( AXI_ID_W   ),
        .AXI_USER_WIDTH ( AXI_USER_W )
    ) axi_vif_t;

    typedef virtual APB_BUS #(
        .APB_ADDR_WIDTH ( APB_ADDR_W ),
        .APB_DATA_WIDTH ( APB_DATA_W )
    ) apb_vif_t;

    // ---- AXI master agent ----
    `include "axi_agent/axi_item.sv"
    `include "axi_agent/axi_sequencer.sv"
    `include "axi_agent/axi_driver.sv"
    `include "axi_agent/axi_monitor.sv"
    `include "axi_agent/axi_agent.sv"

    // ---- APB slave agent ----
    `include "apb_agent/apb_agent_cfg.sv"
    `include "apb_agent/apb_item.sv"
    `include "apb_agent/apb_driver.sv"
    `include "apb_agent/apb_monitor.sv"
    `include "apb_agent/apb_agent.sv"

endpackage : axi2apb_pkg
