// -----------------------------------------------------------------------------
// Assertions (SVA): har clock par signals ke rules. Fail hone par UVM_ERROR banta hai,
// is liye test FAIL hota hai.
// -----------------------------------------------------------------------------
module axi2apb_checker (AXI_BUS axi, APB_BUS apb);

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk, rst_n;
    assign clk   = axi.clk;
    assign rst_n = axi.rst_n;

    // ---- APB: wait ke dauran control aur address stable rehne chahiyein (VP-WW-01, VP-RW-01) ----
    A_APB_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (apb.penable && !apb.pready) |=> (apb.penable && $stable(apb.paddr) && $stable(apb.pwrite)))
        else `uvm_error("A_APB_STABLE", "APB PENABLE/PADDR/PWRITE badla jabke PREADY low tha")

    // ---- APB write: data bhi stable (read mein PWDATA ka koi matlab nahi) ----
    A_APB_WDATA_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (apb.penable && !apb.pready && apb.pwrite) |=> $stable(apb.pwdata))
        else `uvm_error("A_APB_WDATA_STABLE", "PWDATA badla jabke PREADY low tha")

    // ---- Is DUT mein PSEL hamesha 1 hai (spec ka observation; documented) ----
    A_PSEL_CONST: assert property (@(posedge clk) disable iff (!rst_n) apb.psel === 1'b1)
        else `uvm_error("A_PSEL_CONST", "PSEL 1 nahi raha")

    // ---- Response hamesha OKAY (is RTL ka asli behaviour; PSLVERR use nahi hota) ----
    A_RESP_OKAY_B: assert property (@(posedge clk) disable iff (!rst_n)
        axi.b_valid |-> (axi.b_resp == 2'b00))
        else `uvm_error("A_RESP_OKAY_B", "BRESP OKAY nahi")
    A_RESP_OKAY_R: assert property (@(posedge clk) disable iff (!rst_n)
        axi.r_valid |-> (axi.r_resp == 2'b00))
        else `uvm_error("A_RESP_OKAY_R", "RRESP OKAY nahi")

    // ---- Read response mein RLAST hamesha 1 (VP-RV-02) ----
    A_R_LAST: assert property (@(posedge clk) disable iff (!rst_n)
        axi.r_valid |-> axi.r_last)
        else `uvm_error("A_R_LAST", "RVALID ke saath RLAST 0 hai")

    // ---- VALID jab tak READY na aaye, VALID aur payload stable (AXI ka rule) ----
    A_B_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (axi.b_valid && !axi.b_ready) |=> (axi.b_valid && $stable(axi.b_id) && $stable(axi.b_resp)))
        else `uvm_error("A_B_STABLE", "B channel BREADY se pehle badla")
    A_R_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (axi.r_valid && !axi.r_ready) |=> (axi.r_valid && $stable(axi.r_id) && $stable(axi.r_data) && $stable(axi.r_last)))
        else `uvm_error("A_R_STABLE", "R channel RREADY se pehle badla")
    A_AW_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (axi.aw_valid && !axi.aw_ready) |=> (axi.aw_valid && $stable(axi.aw_addr) && $stable(axi.aw_id)))
        else `uvm_error("A_AW_STABLE", "AW channel AWREADY se pehle badla")
    A_W_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (axi.w_valid && !axi.w_ready) |=> (axi.w_valid && $stable(axi.w_data) && $stable(axi.w_last)))
        else `uvm_error("A_W_STABLE", "W channel WREADY se pehle badla")
    A_AR_STABLE: assert property (@(posedge clk) disable iff (!rst_n)
        (axi.ar_valid && !axi.ar_ready) |=> (axi.ar_valid && $stable(axi.ar_addr) && $stable(axi.ar_id)))
        else `uvm_error("A_AR_STABLE", "AR channel ARREADY se pehle badla")

    // ---- cover: ye surat dekhi gayi ya nahi ----
    C_APB_WAIT:    cover property (@(posedge clk) disable iff (!rst_n) apb.penable && !apb.pready);
    C_APB_PSLVERR: cover property (@(posedge clk) disable iff (!rst_n) apb.penable && apb.pready && apb.pslverr);

endmodule
