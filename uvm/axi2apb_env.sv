// Env: AXI agent + APB agent + scoreboard + coverage
class axi2apb_env extends uvm_env;
    `uvm_component_utils(axi2apb_env)

    axi_agent            axi_agt;
    apb_agent            apb_agt;
    axi2apb_scoreboard   sb;
    axi2apb_coverage     cov;
    apb_agent_cfg        apb_cfg;     // test isay run_phase mein badal sakta hai

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        apb_cfg = apb_agent_cfg::type_id::create("apb_cfg");
        uvm_config_db#(apb_agent_cfg)::set(this, "apb_agt*", "cfg", apb_cfg);

        axi_agt = axi_agent::type_id::create("axi_agt", this);
        apb_agt = apb_agent::type_id::create("apb_agt", this);
        sb      = axi2apb_scoreboard::type_id::create("sb", this);
        cov     = axi2apb_coverage::type_id::create("cov", this);
    endfunction

    // Monitors ke radio scoreboard aur coverage dono ke kaanon se jodo
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        axi_agt.mon.ap.connect(sb.axi_imp);
        apb_agt.mon.ap.connect(sb.apb_imp);
        axi_agt.mon.ap.connect(cov.axi_imp);
        apb_agt.mon.ap.connect(cov.apb_imp);
    endfunction
endclass
