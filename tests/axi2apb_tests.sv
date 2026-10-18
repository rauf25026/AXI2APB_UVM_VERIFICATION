// -----------------------------------------------------------------------------
// Tests. Har test aakhir mein "TEST PASSED" ya "TEST FAILED" chhapta hai.
// -----------------------------------------------------------------------------
class axi2apb_base_test extends uvm_test;
    `uvm_component_utils(axi2apb_base_test)

    axi2apb_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi2apb_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();            // poora UVM tree chhap do
    endfunction

    // Har test is ko apni stimulus se badalta hai
    virtual task run_stimulus();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);         // "main kaam kar raha hoon, simulation mat roko"
        run_stimulus();
        #200ns;                              // monitors ko aakhri items nipatane do
        phase.drop_objection(this);          // "kaam khatam"
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        super.report_phase(phase);
        svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL) == 0)
            `uvm_info("RESULT", "TEST PASSED", UVM_NONE)
        else
            `uvm_info("RESULT", "TEST FAILED", UVM_NONE)
    endfunction
endclass


// Bring-up test: 3 write -> read-back (data sequence ke andar compare hota hai)
class bringup_test extends axi2apb_base_test;
    `uvm_component_utils(bringup_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_write_read_seq seq = axi_write_read_seq::type_id::create("seq");
        seq.num_txns = 3;
        seq.start(env.axi_agt.sqr);          // sequence ko AXI sequencer par chalao
    endtask
endclass


// Plan: wr_wait_test (VP-WW-01..03). Sirf writes, APB slave mein 3 se 8 extra wait cycles
class wr_wait_test extends axi2apb_base_test;
    `uvm_component_utils(wr_wait_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_write_seq seq = axi_write_seq::type_id::create("seq");
        env.apb_cfg.min_wait = 3;
        env.apb_cfg.max_wait = 8;
        seq.num_txns = 10;
        seq.start(env.axi_agt.sqr);
    endtask
endclass


// Plan: rd_wait_test (VP-RW-01..03). Sirf reads, APB slave mein 3 se 8 extra wait cycles
class rd_wait_test extends axi2apb_base_test;
    `uvm_component_utils(rd_wait_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_read_seq seq = axi_read_seq::type_id::create("seq");
        env.apb_cfg.min_wait = 3;
        env.apb_cfg.max_wait = 8;
        seq.num_txns = 10;
        seq.start(env.axi_agt.sqr);
    endtask
endclass


// Plan: b2b_wr_test (VP-B2B-02). 20 writes lagatar
class b2b_wr_test extends axi2apb_base_test;
    `uvm_component_utils(b2b_wr_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_write_seq seq = axi_write_seq::type_id::create("seq");
        seq.num_txns = 20;
        seq.start(env.axi_agt.sqr);
    endtask
endclass


// Plan: b2b_rd_test (VP-B2B-01). 20 reads lagatar
class b2b_rd_test extends axi2apb_base_test;
    `uvm_component_utils(b2b_rd_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_read_seq seq = axi_read_seq::type_id::create("seq");
        seq.num_txns = 20;
        seq.start(env.axi_agt.sqr);
    endtask
endclass


// Plan: mixed_rw_test (VP-B2B-03). Read aur write random mix
class mixed_rw_test extends axi2apb_base_test;
    `uvm_component_utils(mixed_rw_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_random_seq seq = axi_random_seq::type_id::create("seq");
        seq.num_txns = 30;
        seq.start(env.axi_agt.sqr);
    endtask
endclass


// Plan: pslverr_test (VP-ERR-01..03). APB slave 50% transfers par PSLVERR=1 deta hai.
// Pass hone ka matlab: DUT PSLVERR ko ignore karta hai (BRESP/RRESP OKAY rehte hain).
class pslverr_test extends axi2apb_base_test;
    `uvm_component_utils(pslverr_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi_random_seq seq = axi_random_seq::type_id::create("seq");
        env.apb_cfg.slverr_pct = 50;
        seq.num_txns = 30;
        seq.start(env.axi_agt.sqr);
    endtask
endclass
