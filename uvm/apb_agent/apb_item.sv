// APB transaction (aik transfer). Monitor isay bharta hai.
class apb_item extends uvm_sequence_item;

    bit [APB_ADDR_W-1:0] addr;
    bit [APB_DATA_W-1:0] wdata;         // write transfer par valid
    bit [APB_DATA_W-1:0] rdata;         // read transfer par valid
    bit                  write;
    bit                  pslverr;
    int unsigned         wait_cycles;   // PENABLE high aur PREADY low wale cycles

    `uvm_object_utils(apb_item)

    function new(string name = "apb_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        if (write)
            return $sformatf("APB WRITE addr=0x%08h wdata=0x%08h pslverr=%0b wait=%0d",
                             addr, wdata, pslverr, wait_cycles);
        else
            return $sformatf("APB READ  addr=0x%08h rdata=0x%08h pslverr=%0b wait=%0d",
                             addr, rdata, pslverr, wait_cycles);
    endfunction
endclass
