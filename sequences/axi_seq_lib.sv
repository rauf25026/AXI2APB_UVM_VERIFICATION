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
