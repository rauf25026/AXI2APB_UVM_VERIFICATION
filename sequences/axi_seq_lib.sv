// -----------------------------------------------------------------------------
// AXI sequences
//   axi_base_seq       : do_write() / do_read() madadgar tasks
//   axi_write_read_seq : write karo, wohi address read karo, data compare karo
// -----------------------------------------------------------------------------
class axi_base_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_base_seq)

    function new(string name = "axi_base_seq");
        super.new(name);
    endfunction

    // Aik write: item banao, randomize karo (kuch fields fix), driver ko do
    task do_write(input  bit [AXI_ADDR_W-1:0] a,
                  input  bit [AXI_DATA_W-1:0] d,
                  input  bit [AXI_ID_W-1:0]   i,
                  output axi_item             t);
        t = axi_item::type_id::create("wr_item");
        start_item(t);                                   // driver se izazat
        if (!t.randomize() with { kind == AXI_WRITE; addr == a; id == i; len == 0; wdata[0] == d; })
            `uvm_fatal("RAND", "write item randomize fail")
        finish_item(t);                                  // driver ke khatam hone tak ruko
    endtask

    task do_read(input  bit [AXI_ADDR_W-1:0] a,
                 input  bit [AXI_ID_W-1:0]   i,
                 output axi_item             t);
        t = axi_item::type_id::create("rd_item");
        start_item(t);
        if (!t.randomize() with { kind == AXI_READ; addr == a; id == i; len == 0; })
            `uvm_fatal("RAND", "read item randomize fail")
        finish_item(t);
    endtask
endclass


class axi_write_read_seq extends axi_base_seq;
    `uvm_object_utils(axi_write_read_seq)

    int unsigned         num_txns  = 3;
    bit [AXI_ADDR_W-1:0] addr_base = 32'h0000_1000;

    function new(string name = "axi_write_read_seq");
        super.new(name);
    endfunction

    task body();
        axi_item             wr, rd;
        bit [AXI_ADDR_W-1:0] a;
        bit [AXI_DATA_W-1:0] d;
        bit [AXI_ID_W-1:0]   i;

        for (int n = 0; n < num_txns; n++) begin
            a = addr_base + 4 * n;                  // har baar nayi (4-byte aligned) jagah
            d = $urandom();
            i = $urandom();

            do_write(a, d, i, wr);
            if (wr.timed_out)
                `uvm_error("WR_RD", $sformatf("write timeout addr=0x%08h", a))
            else begin
                if (wr.bresp !== 2'b00)
                    `uvm_error("WR_RD", $sformatf("BRESP=%0d (OKAY expected)", wr.bresp))
                if (wr.resp_id !== i)
                    `uvm_error("WR_RD", $sformatf("BID=0x%0h expected 0x%0h", wr.resp_id, i))
            end

            do_read(a, i, rd);
            if (rd.timed_out)
                `uvm_error("WR_RD", $sformatf("read timeout addr=0x%08h", a))
            else if (rd.rdata.size() == 0)
                `uvm_error("WR_RD", "read se koi data nahi aaya")
            else begin
                if (rd.rdata[0] !== d)
                    `uvm_error("WR_RD", $sformatf("MISMATCH addr=0x%08h wrote=0x%08h read=0x%08h", a, d, rd.rdata[0]))
                if (rd.rresp[0] !== 2'b00)
                    `uvm_error("WR_RD", $sformatf("RRESP=%0d (OKAY expected)", rd.rresp[0]))
                if (rd.resp_id !== i)
                    `uvm_error("WR_RD", $sformatf("RID=0x%0h expected 0x%0h", rd.resp_id, i))
            end
        end
    endtask
endclass


// Sirf writes (random data). Compare scoreboard karta hai (AXI ki taraf se APB ki taraf).
class axi_write_seq extends axi_base_seq;
    `uvm_object_utils(axi_write_seq)

    int unsigned         num_txns  = 5;
    bit [AXI_ADDR_W-1:0] addr_base = 32'h0000_2000;

    function new(string name = "axi_write_seq");
        super.new(name);
    endfunction

    task body();
        axi_item wr;
        for (int n = 0; n < num_txns; n++) begin
            do_write(addr_base + 4 * n, $urandom(), $urandom(), wr);
            if (wr.timed_out)
                `uvm_error("WR_SEQ", $sformatf("write %0d timeout", n))
        end
    endtask
endclass


// Sirf reads. Jis address par kabhi write nahi hua wahan APB slave default data deta hai.
class axi_read_seq extends axi_base_seq;
    `uvm_object_utils(axi_read_seq)

    int unsigned         num_txns  = 5;
    bit [AXI_ADDR_W-1:0] addr_base = 32'h0000_3000;

    function new(string name = "axi_read_seq");
        super.new(name);
    endfunction

    task body();
        axi_item rd;
        for (int n = 0; n < num_txns; n++) begin
            do_read(addr_base + 4 * n, $urandom(), rd);
            if (rd.timed_out)
                `uvm_error("RD_SEQ", $sformatf("read %0d timeout", n))
        end
    endtask
endclass


// Random mix: kabhi read, kabhi write, random address/data/ID. Compare scoreboard karta hai.
class axi_random_seq extends axi_base_seq;
    `uvm_object_utils(axi_random_seq)

    int unsigned num_txns = 20;

    function new(string name = "axi_random_seq");
        super.new(name);
    endfunction

    task body();
        axi_item t;
        for (int n = 0; n < num_txns; n++) begin
            t = axi_item::type_id::create("rnd_item");
            start_item(t);
            // address chhote window (0x0 se 0xFFF) mein, taake wahi address dobara aaye
            if (!t.randomize() with { addr[AXI_ADDR_W-1:12] == 0; })
                `uvm_fatal("RAND", "random item randomize fail")
            finish_item(t);
            if (t.timed_out)
                `uvm_error("RND_SEQ", {"timeout: ", t.convert2string()})
        end
    endtask
endclass


// Wide random: poori address range aur data ke khas patterns (coverage ke liye)
class axi_wide_seq extends axi_base_seq;
    `uvm_object_utils(axi_wide_seq)

    int unsigned num_txns = 60;

    function new(string name = "axi_wide_seq");
        super.new(name);
    endfunction

    function bit [AXI_ADDR_W-1:0] pick_addr();
        case ($urandom_range(4, 0))
            0:       return 32'h0000_0000;
            1:       return 32'hFFFF_FFFC;
            2:       return {$urandom_range(32'h0FFF_FFFF, 32'h0), 2'b00} & 32'h0FFF_FFFC;
            3:       return $urandom() & 32'hFFFF_FFFC;
            default: return {20'h0, $urandom_range(12'hFFC, 12'h0)} & 32'hFFC;
        endcase
    endfunction

    function bit [AXI_DATA_W-1:0] pick_data();
        case ($urandom_range(4, 0))
            0:       return 32'h0000_0000;
            1:       return 32'hFFFF_FFFF;
            2:       return 32'hAAAA_AAAA;
            3:       return 32'h5555_5555;
            default: return $urandom();
        endcase
    endfunction

    task body();
        axi_item             t;
        bit [AXI_ADDR_W-1:0] a;
        for (int n = 0; n < num_txns; n++) begin
            a = pick_addr();
            t = axi_item::type_id::create("wide_item");
            start_item(t);
            if (!t.randomize() with { addr == a; })
                `uvm_fatal("RAND", "wide item randomize fail")
            if (t.kind == AXI_WRITE) t.wdata[0] = pick_data();
            finish_item(t);
            if (t.timed_out)
                `uvm_error("WIDE_SEQ", {"timeout: ", t.convert2string()})
        end
    endtask
endclass
