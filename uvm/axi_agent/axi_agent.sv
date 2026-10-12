// AXI agent: sequencer + driver + monitor ka dabba
class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)

    axi_sequencer sqr;
    axi_driver    drv;
    axi_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // build_phase: bachche banao
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = axi_monitor::type_id::create("mon", this);      // monitor hamesha
        if (is_active == UVM_ACTIVE) begin                     // baaqi sirf active mode mein
            sqr = axi_sequencer::type_id::create("sqr", this);
            drv = axi_driver::type_id::create("drv", this);
        end
    endfunction

    // connect_phase: driver ko sequencer se jodo
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
