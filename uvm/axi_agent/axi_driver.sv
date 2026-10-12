// -----------------------------------------------------------------------------
// AXI master driver.
//   Write : AW aur W channel saath saath bhejta hai (fork), phir B ka intezar.
//   Read  : AR bhejta hai, phir R beat ka intezar (rlast tak).
// Abhi koi delay ya backpressure nahi (wo agle steps mein item mein jodenge).
// Har item ke shuru mein clock edge ka intezar hota hai taake drive hamesha
// edge se aligned rahe.
// -----------------------------------------------------------------------------
class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)

    axi_vif_t    vif;                    // asli pins ka handle
    int unsigned timeout_cycles = 2000;  // handshake ka intezar is se zyada nahi

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // build_phase: vif ko config_db (notice board) se uthao
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi_vif_t)::get(this, "", "axi_vif", vif))
            `uvm_fatal("NOVIF", "axi_vif config_db mein nahi mila (tb_top ne set nahi kiya)")
    endfunction

    // run_phase: asli kaam. Item lo, pins par chalao, wapas batao
    task run_phase(uvm_phase phase);
        init_signals();
        wait (vif.rst_n === 1'b1);          // reset khatam hone ka intezar
        repeat (2) @(vif.drv_cb);
        forever begin
            seq_item_port.get_next_item(req);   // sequencer se agla item
            drive_item(req);
            seq_item_port.item_done();          // sequencer ko batao ke item mukammal
        end
    endtask

    // Saare outputs 0 par
    task init_signals();
        vif.drv_cb.aw_valid <= 1'b0;  vif.drv_cb.w_valid <= 1'b0;  vif.drv_cb.b_ready <= 1'b0;
        vif.drv_cb.ar_valid <= 1'b0;  vif.drv_cb.r_ready <= 1'b0;
        vif.drv_cb.aw_id <= '0;     vif.drv_cb.aw_addr <= '0;     vif.drv_cb.aw_len <= '0;
        vif.drv_cb.aw_size <= '0;   vif.drv_cb.aw_burst <= '0;    vif.drv_cb.aw_lock <= 1'b0;
        vif.drv_cb.aw_cache <= '0;  vif.drv_cb.aw_prot <= '0;     vif.drv_cb.aw_region <= '0;
        vif.drv_cb.aw_user <= '0;   vif.drv_cb.aw_qos <= '0;
        vif.drv_cb.w_data <= '0;    vif.drv_cb.w_strb <= '0;      vif.drv_cb.w_last <= 1'b0;
        vif.drv_cb.w_user <= '0;
        vif.drv_cb.ar_id <= '0;     vif.drv_cb.ar_addr <= '0;     vif.drv_cb.ar_len <= '0;
        vif.drv_cb.ar_size <= '0;   vif.drv_cb.ar_burst <= '0;    vif.drv_cb.ar_lock <= 1'b0;
        vif.drv_cb.ar_cache <= '0;  vif.drv_cb.ar_prot <= '0;     vif.drv_cb.ar_region <= '0;
        vif.drv_cb.ar_user <= '0;   vif.drv_cb.ar_qos <= '0;
    endtask

    task drive_item(axi_item t);
        t.timed_out = 1'b0;
        @(vif.drv_cb);                       // clock edge se align
        if (t.kind == AXI_WRITE) do_write(t);
        else                     do_read(t);
    endtask

    // ------------------------------------------------------------ WRITE
    task do_write(axi_item t);
        fork
            send_aw(t);                      // AW aur W aik saath
            send_w(t);
        join
        recv_b(t);                           // phir B response
    endtask

    task send_aw(axi_item t);
        int unsigned n = 0;
        vif.drv_cb.aw_id     <= t.id;
        vif.drv_cb.aw_addr   <= t.addr;
        vif.drv_cb.aw_len    <= t.len;
        vif.drv_cb.aw_size   <= t.size;
        vif.drv_cb.aw_burst  <= t.burst;
        vif.drv_cb.aw_lock   <= t.lock;
        vif.drv_cb.aw_cache  <= t.cache;
        vif.drv_cb.aw_prot   <= t.prot;
        vif.drv_cb.aw_region <= t.region;
        vif.drv_cb.aw_user   <= t.user;
        vif.drv_cb.aw_qos    <= t.qos;
        vif.drv_cb.aw_valid  <= 1'b1;        // VALID uthao
        forever begin
            @(vif.drv_cb);
            if (vif.drv_cb.aw_ready === 1'b1) break;   // READY mila: handshake mukammal
            n++;
            if (n >= timeout_cycles) begin
                `uvm_error("AXI_DRV", "AW handshake timeout")
                t.timed_out = 1'b1;
                break;
            end
        end
        vif.drv_cb.aw_valid <= 1'b0;         // VALID gira do
    endtask

    task send_w(axi_item t);
        int unsigned n;
        for (int i = 0; i <= t.len; i++) begin   // len+1 beats
            vif.drv_cb.w_data  <= t.wdata[i];
            vif.drv_cb.w_strb  <= t.wstrb[i];
            vif.drv_cb.w_last  <= (i == t.len);  // aakhri beat par WLAST
            vif.drv_cb.w_user  <= t.user;
            vif.drv_cb.w_valid <= 1'b1;
            n = 0;
            forever begin
                @(vif.drv_cb);
                if (vif.drv_cb.w_ready === 1'b1) break;
                n++;
                if (n >= timeout_cycles) begin
                    `uvm_error("AXI_DRV", "W handshake timeout")
                    t.timed_out = 1'b1;
                    break;
                end
            end
            if (t.timed_out) break;
        end
        vif.drv_cb.w_valid <= 1'b0;
        vif.drv_cb.w_last  <= 1'b0;
    endtask

    task recv_b(axi_item t);
        int unsigned n = 0;
        vif.drv_cb.b_ready <= 1'b1;          // main response lene ko tayyar hoon
        forever begin
            @(vif.drv_cb);
            if (vif.drv_cb.b_valid === 1'b1) begin
                t.bresp   = vif.drv_cb.b_resp;
                t.resp_id = vif.drv_cb.b_id;
                break;
            end
            n++;
            if (n >= timeout_cycles) begin
                `uvm_error("AXI_DRV", "B response timeout")
                t.timed_out = 1'b1;
                break;
            end
        end
        vif.drv_cb.b_ready <= 1'b0;
    endtask

    // ------------------------------------------------------------ READ
    task do_read(axi_item t);
        int unsigned n = 0;
        vif.drv_cb.ar_id     <= t.id;
        vif.drv_cb.ar_addr   <= t.addr;
        vif.drv_cb.ar_len    <= t.len;
        vif.drv_cb.ar_size   <= t.size;
        vif.drv_cb.ar_burst  <= t.burst;
        vif.drv_cb.ar_lock   <= t.lock;
        vif.drv_cb.ar_cache  <= t.cache;
        vif.drv_cb.ar_prot   <= t.prot;
        vif.drv_cb.ar_region <= t.region;
        vif.drv_cb.ar_user   <= t.user;
        vif.drv_cb.ar_qos    <= t.qos;
        vif.drv_cb.ar_valid  <= 1'b1;
        forever begin
            @(vif.drv_cb);
            if (vif.drv_cb.ar_ready === 1'b1) break;
            n++;
            if (n >= timeout_cycles) begin
                `uvm_error("AXI_DRV", "AR handshake timeout")
                t.timed_out = 1'b1;
                break;
            end
        end
        vif.drv_cb.ar_valid <= 1'b0;
        if (t.timed_out) return;

        // R channel: rlast tak beats jama karo
        n = 0;
        vif.drv_cb.r_ready <= 1'b1;
        forever begin
            @(vif.drv_cb);
            if (vif.drv_cb.r_valid === 1'b1) begin
                t.rdata.push_back(vif.drv_cb.r_data);
                t.rresp.push_back(vif.drv_cb.r_resp);
                t.resp_id = vif.drv_cb.r_id;
                n = 0;
                if (vif.drv_cb.r_last === 1'b1) break;
            end else begin
                n++;
                if (n >= timeout_cycles) begin
                    `uvm_error("AXI_DRV", "R data timeout")
                    t.timed_out = 1'b1;
                    break;
                end
            end
        end
        vif.drv_cb.r_ready <= 1'b0;
    endtask

endclass
