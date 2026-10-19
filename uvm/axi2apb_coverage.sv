// -----------------------------------------------------------------------------
// Functional coverage: dono monitors ki transactions sun kar covergroups bharta hai.
// -----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_cov_axi)
`uvm_analysis_imp_decl(_cov_apb)

class axi2apb_coverage extends uvm_component;
    `uvm_component_utils(axi2apb_coverage)

    uvm_analysis_imp_cov_axi #(axi_item, axi2apb_coverage) axi_imp;
    uvm_analysis_imp_cov_apb #(apb_item, axi2apb_coverage) apb_imp;

    // covergroups jin variables ko dekhte hain
    bit                  a_write;
    bit [AXI_ID_W-1:0]   a_id;
    bit [AXI_DATA_W-1:0] a_data;
    bit                  p_write;
    int unsigned         p_wait;
    bit                  p_err;
    bit [APB_ADDR_W-1:0] p_addr;
    bit [APB_DATA_W-1:0] p_data;

    // AXI taraf: read/write, ID values, write data ke patterns
    covergroup cg_axi;
        option.per_instance = 1;
        cp_kind: coverpoint a_write { bins rd = {0}; bins wr = {1}; }
        cp_id:   coverpoint a_id    { bins zero = {0}; bins id_small = {[1:15]}; bins id_large = {[16:$]}; }
        cp_wdata: coverpoint a_data iff (a_write) {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins alt   = {32'hAAAAAAAA, 32'h55555555};
            bins other = {[1:32'hFFFFFFFE]};
        }
    endgroup

    // APB taraf: direction, wait cycles, PSLVERR, address ranges, write data patterns
    covergroup cg_apb;
        option.per_instance = 1;
        cp_dir:  coverpoint p_write { bins rd = {0}; bins wr = {1}; }
        cp_wait: coverpoint p_wait  { bins w1 = {1}; bins w2_4 = {[2:4]}; bins w5_plus = {[5:$]}; }
        cp_err:  coverpoint p_err   { bins no = {0}; bins yes = {1}; }
        cp_addr: coverpoint p_addr  {
            bins low  = {[32'h0:32'hFFF]};
            bins mid  = {[32'h1000:32'h0FFFFFFF]};
            bins high = {[32'h10000000:32'hFFFFFFFB]};
            bins top  = {[32'hFFFFFFFC:32'hFFFFFFFF]};
        }
        cx_dir_wait:     cross cp_dir, cp_wait;
        cx_dir_wait_err: cross cp_dir, cp_wait, cp_err;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_axi = new();
        cg_apb = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_imp = new("axi_imp", this);
        apb_imp = new("apb_imp", this);
    endfunction

    function void write_cov_axi(axi_item t);
        a_write = (t.kind == AXI_WRITE);
        a_id    = t.id;
        a_data  = (t.wdata.size() > 0) ? t.wdata[0] : '0;
        cg_axi.sample();
    endfunction

    function void write_cov_apb(apb_item t);
        p_write = t.write;
        p_wait  = t.wait_cycles;
        p_err   = t.pslverr;
        p_addr  = t.addr;
        p_data  = t.write ? t.wdata : t.rdata;
        cg_apb.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Functional coverage: axi=%0.1f%% apb=%0.1f%%",
                  cg_axi.get_inst_coverage(), cg_apb.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
