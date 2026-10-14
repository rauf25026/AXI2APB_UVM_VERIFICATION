// APB slave agent: driver + monitor. Sequencer nahi hai, kyun ke driver reactive hai
// aur apna behaviour cfg object se leta hai.
class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver  drv;
    apb_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = apb_monitor::type_id::create("mon", this);       // monitor hamesha
        if (is_active == UVM_ACTIVE)
            drv = apb_driver::type_id::create("drv", this);    // driver sirf active mode mein
    endfunction
endclass
