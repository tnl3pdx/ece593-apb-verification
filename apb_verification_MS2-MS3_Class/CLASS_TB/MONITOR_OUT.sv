class MONITOR_OUT;
	int tx_count;
	virtual apb_external_if vif;
	mailbox mon_out2scb;
	bit prev_ready;

	function new(virtual apb_external_if ext_if, mailbox mon_out2scb);
		this.vif = ext_if;
		this.mon_out2scb = mon_out2scb;
		this.tx_count = 0;
		this.prev_ready = ext_if.ready;
	endfunction

	task start();
		$display("[MONITOR_OUT] STARTED");
		forever begin
			TRANSACTION tx = new();
			@(posedge vif.clk);
			if (vif.ready && !prev_ready) begin
				tx.addr = vif.addr;
				tx.data_out = vif.data_out;
				tx.rw = vif.rw;
				tx.valid = vif.valid;
				$display("[MONITOR_OUT] Observed completed transaction #%0d: ADDR=0x%08x, DATA=0x%08x, RW=%b", tx_count, tx.addr, tx.data_out, tx.rw);
				mon_out2scb.put(tx);
				tx_count++;
			end
			prev_ready = vif.ready;
		end
		$display("[MONITOR_OUT] FINISHED");
	endtask

endclass : MONITOR_OUT