// APB monitor (passive): transfer tab mukammal hota hai jab psel && penable && pready.
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    uvm_analysis_port #(apb_item) ap;    // radio: scoreboard/coverage yahan se sunenge
    apb_vif_t vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(apb_vif_t)::get(this, "", "apb_vif", vif))
            `uvm_fatal("NOVIF", "apb_vif config_db mein nahi mila")
    endfunction

    task run_phase(uvm_phase phase);
        apb_item     it;
        int unsigned wcnt = 0;               // PREADY low wale cycles ginta hai
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            if (vif.rst_n !== 1'b1) begin
                wcnt = 0;
                continue;
            end
            if (vif.mon_cb.psel === 1'b1 && vif.mon_cb.penable === 1'b1) begin
                if (vif.mon_cb.pready === 1'b1) begin       // transfer mukammal
                    it = apb_item::type_id::create("apb_tr");
                    it.addr        = vif.mon_cb.paddr;
                    it.write       = vif.mon_cb.pwrite;
                    it.wdata       = vif.mon_cb.pwdata;
                    it.rdata       = vif.mon_cb.pwrite ? '0 : vif.mon_cb.prdata;
                    it.pslverr     = vif.mon_cb.pslverr;
                    it.wait_cycles = wcnt;
                    wcnt = 0;
                    `uvm_info("APB_MON", it.convert2string(), UVM_MEDIUM)
                    ap.write(it);                           // radio par broadcast
                end else begin
                    wcnt++;                                 // abhi wait chal raha hai
                end
            end
        end
    endtask
endclass
