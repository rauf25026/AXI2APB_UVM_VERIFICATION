// -----------------------------------------------------------------------------
// Scoreboard: AXI monitor aur APB monitor ki transactions compare karta hai.
// Plan ke checks: SB-WR (address/data), SB-RD (address/data/ID/beat), SB-RESP (BRESP/BID).
//
// Order: APB item hamesha AXI item se pehle aata hai (B/R response APB transfer ke baad
// aati hai), is liye APB items queue mein rakhte hain aur AXI item aane par compare karte hain.
// Read aur write ki queues alag hain (AXI mein inka aapas mein order nahi hota).
//
// Mutation check: +MUT=<n> par input mein jaan boojh kar kharabi daali jati hai taake
// dekha ja sake ke scoreboard use pakarta hai. Default MUT=0 mein kuch nahi badalta.
// -----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class axi2apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi2apb_scoreboard)

    uvm_analysis_imp_axi #(axi_item, axi2apb_scoreboard) axi_imp;
    uvm_analysis_imp_apb #(apb_item, axi2apb_scoreboard) apb_imp;

    apb_item apb_wr_q[$];     // APB writes jo AXI write ka intezar kar rahe hain
    apb_item apb_rd_q[$];     // APB reads jo AXI read ka intezar kar rahe hain

    int unsigned wr_ok, rd_ok, errors;
    int unsigned apb_wr_seen;     // mutation 4 ke liye: kitni APB writes dekhi
    int          mut = 0;         // mutation number (0 = band)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_imp = new("axi_imp", this);
        apb_imp = new("apb_imp", this);
        if (!$value$plusargs("MUT=%d", mut)) mut = 0;
        if (mut != 0)
            `uvm_info("SB", $sformatf("MUTATION %0d ACTIVE: jaan boojh kar kharabi daali ja rahi hai", mut), UVM_NONE)
    endfunction

    // APB monitor ne item bheja: direction ke hisaab se queue mein rakho
    function void write_apb(apb_item t);
        if (t.write) apb_wr_seen++;

        // ---- mutation hooks (sirf +MUT=n par chalte hain) ----
        if (mut == 1) t.addr  = t.addr ^ 32'h4;                     // address ka bit 2 ulta
        if (mut == 2 && t.write)  t.wdata = t.wdata ^ 32'h1;        // write data ka bit 0 ulta
        if (mut == 3 && !t.write) t.rdata = t.rdata ^ 32'h1;        // read data ka bit 0 ulta
        if (mut == 4 && t.write && apb_wr_seen == 2) return;        // doosri APB write gayab

        if (t.write) apb_wr_q.push_back(t);
        else         apb_rd_q.push_back(t);
    endfunction

    // AXI monitor ne mukammal transaction bheji: compare karo
    function void write_axi(axi_item t);
        // ---- mutation hooks ----
        if (mut == 5 && t.kind == AXI_WRITE) t.bresp   = 2'b10;             // BRESP = SLVERR
        if (mut == 6 && t.kind == AXI_READ)  t.resp_id = t.resp_id ^ 1;     // RID ghalat

        if (t.kind == AXI_WRITE) check_write(t);
        else                     check_read(t);
    endfunction

    function void check_write(axi_item t);
        apb_item a;
        bit      ok = 1'b1;

        if (apb_wr_q.size() == 0) begin
            `uvm_error("SB_WR", {"AXI write mukammal hui lekin APB write nahi dikhi: ", t.convert2string()})
            errors++;
            return;
        end
        a = apb_wr_q.pop_front();

        if (a.addr !== t.addr[APB_ADDR_W-1:0]) begin
            `uvm_error("SB_WR", $sformatf("PADDR mismatch: AXI addr=0x%08h APB addr=0x%08h", t.addr, a.addr))
            ok = 1'b0;
        end
        if (t.wdata.size() == 0) begin
            `uvm_error("SB_WR", "AXI write item mein koi data nahi")
            ok = 1'b0;
        end else if (a.wdata !== t.wdata[0]) begin
            `uvm_error("SB_WR", $sformatf("PWDATA mismatch: AXI wdata=0x%08h APB wdata=0x%08h", t.wdata[0], a.wdata))
            ok = 1'b0;
        end
        if (t.bresp !== 2'b00) begin
            `uvm_error("SB_RESP", $sformatf("BRESP=%0d (OKAY expected)", t.bresp))
            ok = 1'b0;
        end
        if (t.resp_id !== t.id) begin
            `uvm_error("SB_RESP", $sformatf("BID=0x%0h expected AWID=0x%0h", t.resp_id, t.id))
            ok = 1'b0;
        end

        if (ok) wr_ok++;
        else    errors++;
    endfunction

    function void check_read(axi_item t);
        apb_item a;
        bit      ok = 1'b1;

        if (apb_rd_q.size() == 0) begin
            `uvm_error("SB_RD", {"AXI read mukammal hui lekin APB read nahi dikhi: ", t.convert2string()})
            errors++;
            return;
        end
        a = apb_rd_q.pop_front();

        if (a.addr !== t.addr[APB_ADDR_W-1:0]) begin
            `uvm_error("SB_RD", $sformatf("PADDR mismatch: AXI addr=0x%08h APB addr=0x%08h", t.addr, a.addr))
            ok = 1'b0;
        end
        if (t.rdata.size() != 1) begin
            `uvm_error("SB_RD", $sformatf("R beats=%0d (1 expected)", t.rdata.size()))
            ok = 1'b0;
        end else begin
            if (t.rdata[0] !== a.rdata) begin
                `uvm_error("SB_RD", $sformatf("RDATA mismatch: APB PRDATA=0x%08h AXI RDATA=0x%08h", a.rdata, t.rdata[0]))
                ok = 1'b0;
            end
            if (t.rresp[0] !== 2'b00) begin
                `uvm_error("SB_RD", $sformatf("RRESP=%0d (OKAY expected)", t.rresp[0]))
                ok = 1'b0;
            end
        end
        if (t.resp_id !== t.id) begin
            `uvm_error("SB_RD", $sformatf("RID=0x%0h expected ARID=0x%0h", t.resp_id, t.id))
            ok = 1'b0;
        end

        if (ok) rd_ok++;
        else    errors++;
    endfunction

    // Simulation ke aakhir mein: koi APB transfer baqi to nahi reh gayi?
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (apb_wr_q.size() != 0)
            `uvm_error("SB_WR", $sformatf("%0d APB write(s) ka koi AXI write nahi mila", apb_wr_q.size()))
        if (apb_rd_q.size() != 0)
            `uvm_error("SB_RD", $sformatf("%0d APB read(s) ka koi AXI read nahi mila", apb_rd_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB", $sformatf("MUT=%0d writes matched=%0d reads matched=%0d errors=%0d", mut, wr_ok, rd_ok, errors), UVM_NONE)
    endfunction

endclass
