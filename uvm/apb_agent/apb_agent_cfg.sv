// APB slave ka behaviour tay karne wale knobs. Test inhein badal sakta hai.
class apb_agent_cfg extends uvm_object;
    `uvm_object_utils(apb_agent_cfg)

    // Hamare slave mein kam az kam 1 wait cycle hamesha hota hai (neeche driver ka note dekhein).
    // Ye knobs us ke ooper extra wait cycles daalte hain.
    int unsigned min_wait   = 0;
    int unsigned max_wait   = 2;
    int unsigned slverr_pct = 0;   // 0..100: kitne % transfers par PSLVERR=1

    function new(string name = "apb_agent_cfg");
        super.new(name);
    endfunction
endclass
