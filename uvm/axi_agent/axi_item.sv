// AXI transaction (aik read ya aik write). Yeh pins nahi, data hai.
typedef enum bit { AXI_READ = 1'b0, AXI_WRITE = 1'b1 } axi_kind_e;

class axi_item extends uvm_sequence_item;

    // ---------------- request (sequence/test chunti hai) ----------------
    rand axi_kind_e           kind;     // read ya write
    rand bit [AXI_ID_W-1:0]   id;
    rand bit [AXI_ADDR_W-1:0] addr;
    rand bit [7:0]            len;      // beats - 1
    rand bit [2:0]            size;
    rand bit [1:0]            burst;
    rand bit                  lock;
    rand bit [3:0]            cache;
    rand bit [2:0]            prot;
    rand bit [3:0]            region;
    rand bit [3:0]            qos;
    rand bit [AXI_USER_W-1:0] user;
    rand bit [AXI_DATA_W-1:0] wdata[$]; // write data (har beat ke liye aik)
    rand bit [AXI_STRB_W-1:0] wstrb[$];

    // ---------------- response (driver/monitor bharte hain) ----------------
    bit [1:0]            bresp;         // write response
    bit [AXI_ID_W-1:0]   resp_id;       // BID ya RID
    bit [AXI_DATA_W-1:0] rdata[$];      // read data
    bit [1:0]            rresp[$];
    bit                  timed_out;     // driver ne handshake ka intezar chhor diya

    // ---------------- knobs (non-random) ----------------
    bit single_beat = 1'b1;   // DUT burst progression nahi karta, is liye default len=0
    bit full_strobe = 1'b1;   // DUT WSTRB use nahi karta, is liye default sab 1
    bit aligned     = 1'b1;   // address 4-byte aligned

    // ---------------- constraints (random ki hadd) ----------------
    constraint c_len     { if (single_beat) len == 0; else len inside {[0:15]}; }
    constraint c_burst   { burst == 2'b01; }                  // INCR
    constraint c_size    { size inside {[0:AXI_SIZE_MAX]}; }
    constraint c_align   { if (aligned) addr[1:0] == 2'b00; }
    constraint c_wdata_q {
        wdata.size() == ((kind == AXI_WRITE) ? (len + 1) : 0);
        wstrb.size() == wdata.size();
    }
    constraint c_strb    { if (full_strobe) foreach (wstrb[i]) wstrb[i] == '1; }

    // UVM factory mein registration
    `uvm_object_utils(axi_item)

    function new(string name = "axi_item");
        super.new(name);
    endfunction

    // log mein chhapne ke liye
    virtual function string convert2string();
        string s;
        s = $sformatf("%s id=0x%0h addr=0x%08h len=%0d size=%0d burst=%0d",
                      kind.name(), id, addr, len, size, burst);
        if (kind == AXI_WRITE) begin
            foreach (wdata[i])
                s = {s, $sformatf(" wd[%0d]=0x%08h", i, wdata[i])};
            s = {s, $sformatf(" | bresp=%0d bid=0x%0h", bresp, resp_id)};
        end else begin
            foreach (rdata[i])
                s = {s, $sformatf(" rd[%0d]=0x%08h", i, rdata[i])};
            s = {s, $sformatf(" | rid=0x%0h", resp_id)};
        end
        if (timed_out) s = {s, " [TIMED OUT]"};
        return s;
    endfunction

endclass
