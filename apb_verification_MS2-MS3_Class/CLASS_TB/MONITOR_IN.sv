class MONITOR_IN;
	virtual apb_external_if vif;
	mailbox mon_in2sb;
	bit prev_start;

	function new(virtual apb_external_if ext_if, mailbox mon_in2sb);
		this.vif = ext_if;
		this.mon_in2sb = mon_in2sb;
		this.prev_start = 0;
	endfunction

	task start();
		$display("[MONITOR_IN] STARTED");
		forever begin
			TRANSACTION tx = new();
			@(posedge vif.clk);
			if (vif.start && !prev_start) begin
				tx.addr = vif.addr;
				tx.data_in = vif.data_in;
				tx.rw = vif.rw;
				$display("[MONITOR_IN] Observed transaction: ADDR=0x%08x, DATA=0x%08x, RW=%b", tx.addr, tx.data_in, tx.rw);
				mon_in2sb.put(tx);
			end
			prev_start = vif.start;
		end
		$display("[MONITOR_IN] FINISHED");
	endtask

endclass : MONITOR_IN