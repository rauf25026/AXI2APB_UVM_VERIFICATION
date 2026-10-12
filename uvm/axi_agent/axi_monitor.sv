// -----------------------------------------------------------------------------
// AXI monitor (passive): pins ko sirf dekhta hai.
//   Write item : AW handshake + W beats (wlast tak) + B handshake -> mukammal hone par broadcast
//   Read  item : AR handshake + R beats (rlast tak)               -> mukammal hone par broadcast
// Bridge aik waqt mein aik hi transaction karta hai, is liye in-order matching kaafi hai.
// -----------------------------------------------------------------------------
class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    uvm_analysis_port #(axi_item) ap;    // radio: scoreboard/coverage yahan se sunenge
    axi_vif_t vif;

    axi_item aw_q[$];                    // AW mil gaya, B ka intezar
    axi_item w_q[$];                     // poora W burst mil gaya, B ka intezar
    axi_item ar_q[$];                    // AR mil gaya, R ka intezar
    axi_item cur_w;                      // jo W burst abhi ban raha hai
    axi_item cur_r;                      // jo R response abhi ban raha hai

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(axi_vif_t)::get(this, "", "axi_vif", vif))
            `uvm_fatal("NOVIF", "axi_vif config_db mein nahi mila")
    endfunction

    task run_phase(uvm_phase phase);
        wait (vif.rst_n === 1'b1);
        flush();
        forever begin
            @(vif.mon_cb);                       // har clock edge par
            if (vif.rst_n !== 1'b1) begin        // reset aaye to sab bhool jao
                flush();
                continue;
            end
            sample_aw();
            sample_w();
            sample_b();
            sample_ar();
            sample_r();
        end
    endtask

    function void flush();
        aw_q.delete();
        w_q.delete();
        ar_q.delete();
        cur_w = axi_item::type_id::create("w_tr");
        cur_r = axi_item::type_id::create("r_tr");
    endfunction

    // ---- Write address channel ----
    function void sample_aw();
        axi_item t;
        if (vif.mon_cb.aw_valid === 1'b1 && vif.mon_cb.aw_ready === 1'b1) begin
            t = axi_item::type_id::create("wr_tr");
            t.kind   = AXI_WRITE;
            t.id     = vif.mon_cb.aw_id;
            t.addr   = vif.mon_cb.aw_addr;
            t.len    = vif.mon_cb.aw_len;
            t.size   = vif.mon_cb.aw_size;
            t.burst  = vif.mon_cb.aw_burst;
            t.lock   = vif.mon_cb.aw_lock;
            t.cache  = vif.mon_cb.aw_cache;
            t.prot   = vif.mon_cb.aw_prot;
            t.region = vif.mon_cb.aw_region;
            t.qos    = vif.mon_cb.aw_qos;
            t.user   = vif.mon_cb.aw_user;
            aw_q.push_back(t);
        end
    endfunction

    // ---- Write data channel ----
    function void sample_w();
        if (vif.mon_cb.w_valid === 1'b1 && vif.mon_cb.w_ready === 1'b1) begin
            cur_w.wdata.push_back(vif.mon_cb.w_data);
            cur_w.wstrb.push_back(vif.mon_cb.w_strb);
            if (vif.mon_cb.w_last === 1'b1) begin     // burst mukammal
                w_q.push_back(cur_w);
                cur_w = axi_item::type_id::create("w_tr");
            end
        end
    endfunction

    // ---- Write response channel: yahan poora write item ban kar broadcast hota hai ----
    function void sample_b();
        axi_item t, w;
        if (vif.mon_cb.b_valid === 1'b1 && vif.mon_cb.b_ready === 1'b1) begin
            if (aw_q.size() == 0 || w_q.size() == 0) begin
                `uvm_error("AXI_MON", "B handshake mila lekin matching AW/W nahi hai")
                return;
            end
            t = aw_q.pop_front();
            w = w_q.pop_front();
            t.wdata   = w.wdata;
            t.wstrb   = w.wstrb;
            t.bresp   = vif.mon_cb.b_resp;
            t.resp_id = vif.mon_cb.b_id;
            `uvm_info("AXI_MON", {"WRITE done: ", t.convert2string()}, UVM_MEDIUM)
            ap.write(t);                              // radio par broadcast
        end
    endfunction

    // ---- Read address channel ----
    function void sample_ar();
        axi_item t;
        if (vif.mon_cb.ar_valid === 1'b1 && vif.mon_cb.ar_ready === 1'b1) begin
            t = axi_item::type_id::create("rd_tr");
            t.kind   = AXI_READ;
            t.id     = vif.mon_cb.ar_id;
            t.addr   = vif.mon_cb.ar_addr;
            t.len    = vif.mon_cb.ar_len;
            t.size   = vif.mon_cb.ar_size;
            t.burst  = vif.mon_cb.ar_burst;
            t.lock   = vif.mon_cb.ar_lock;
            t.cache  = vif.mon_cb.ar_cache;
            t.prot   = vif.mon_cb.ar_prot;
            t.region = vif.mon_cb.ar_region;
            t.qos    = vif.mon_cb.ar_qos;
            t.user   = vif.mon_cb.ar_user;
            ar_q.push_back(t);
        end
    endfunction

    // ---- Read data channel: yahan poora read item ban kar broadcast hota hai ----
    function void sample_r();
        axi_item t;
        if (vif.mon_cb.r_valid === 1'b1 && vif.mon_cb.r_ready === 1'b1) begin
            cur_r.rdata.push_back(vif.mon_cb.r_data);
            cur_r.rresp.push_back(vif.mon_cb.r_resp);
            cur_r.resp_id = vif.mon_cb.r_id;
            if (vif.mon_cb.r_last === 1'b1) begin
                if (ar_q.size() == 0) begin
                    `uvm_error("AXI_MON", "R last mila lekin matching AR nahi hai")
                end else begin
                    t = ar_q.pop_front();
                    t.rdata   = cur_r.rdata;
                    t.rresp   = cur_r.rresp;
                    t.resp_id = cur_r.resp_id;
                    `uvm_info("AXI_MON", {"READ done: ", t.convert2string()}, UVM_MEDIUM)
                    ap.write(t);                      // radio par broadcast
                end
                cur_r = axi_item::type_id::create("r_tr");
            end
        end
    endfunction

endclass
