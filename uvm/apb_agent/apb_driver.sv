// -----------------------------------------------------------------------------
// APB slave (reactive) driver + chhota memory model.
//
// RTL ki observation: PSEL hamesha 1 hai aur PENABLE request ke pehle hi cycle
// mein high ho jata hai (setup phase nahi). DUT PREADY usi cycle mein sample karta
// hai. Hamara PREADY default 0 hai, is liye har transfer mein kam az kam 1 wait
// cycle aata hai; cfg.min_wait / cfg.max_wait us ke ooper extra wait cycles daalte hain.
//
//   edge k      : driver PENABLE dekhta hai (DUT is edge par PREADY=0 dekh chuka)
//   edge k+w    : driver PREADY=1 (+PRDATA, PSLVERR) chalata hai
//   edge k+w+1  : DUT PREADY=1 dekhta hai; driver PREADY wapas 0 karta hai
// -----------------------------------------------------------------------------
class apb_driver extends uvm_component;
    `uvm_component_utils(apb_driver)

    apb_vif_t     vif;
    apb_agent_cfg cfg;

    // Memory model: address -> data (associative array)
    bit [APB_DATA_W-1:0] mem [bit [APB_ADDR_W-1:0]];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_vif_t)::get(this, "", "apb_vif", vif))
            `uvm_fatal("NOVIF", "apb_vif config_db mein nahi mila (tb_top ne set nahi kiya)")
        if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
            cfg = apb_agent_cfg::type_id::create("cfg");     // cfg na mile to default knobs
    endfunction

    // Jis address par kabhi write nahi hua, wahan read ka default data (deterministic)
    function bit [APB_DATA_W-1:0] default_data(bit [APB_ADDR_W-1:0] a);
        return a ^ 32'hA5A5_5A5A;
    endfunction

    task run_phase(uvm_phase phase);
        vif.drv_cb.pready  <= 1'b0;
        vif.drv_cb.prdata  <= '0;
        vif.drv_cb.pslverr <= 1'b0;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.drv_cb);
            if (vif.rst_n !== 1'b1) begin
                vif.drv_cb.pready  <= 1'b0;
                vif.drv_cb.pslverr <= 1'b0;
                continue;
            end
            if (vif.drv_cb.psel === 1'b1 && vif.drv_cb.penable === 1'b1)
                respond();                      // DUT ne request bheji hai
        end
    endtask

    task respond();
        int unsigned         w;
        bit [APB_ADDR_W-1:0] a;
        bit [APB_DATA_W-1:0] wd, rd;
        bit                  wr, err;

        w = $urandom_range(cfg.max_wait, cfg.min_wait);   // extra wait cycles
        repeat (w) @(vif.drv_cb);

        a   = vif.drv_cb.paddr;
        wr  = vif.drv_cb.pwrite;
        wd  = vif.drv_cb.pwdata;
        err = (cfg.slverr_pct > 0) && ($urandom_range(99, 0) < cfg.slverr_pct);

        rd = '0;
        if (wr) begin
            if (!err) mem[a] = wd;              // write: data save karo
        end else begin
            rd = mem.exists(a) ? mem[a] : default_data(a);   // read: save kiya hua ya default
        end

        vif.drv_cb.pready  <= 1'b1;             // jawab do
        vif.drv_cb.prdata  <= rd;
        vif.drv_cb.pslverr <= err;
        @(vif.drv_cb);                          // is edge par DUT PREADY=1 dekhta hai
        vif.drv_cb.pready  <= 1'b0;             // wapas idle
        vif.drv_cb.prdata  <= '0;
        vif.drv_cb.pslverr <= 1'b0;
    endtask

endclass
