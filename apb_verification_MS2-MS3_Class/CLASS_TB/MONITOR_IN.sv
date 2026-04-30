class MONITOR_IN;
	virtual apb_external_if vif;
	mailbox mon_in2sb;
	bit prev_start;

	// Transaction handle specifically for coverage sampling
	TRANSACTION cov_tx; 

	// =========================================================
	// Functional Coverage Model
	// =========================================================
	covergroup apb_cg;
		option.per_instance = 1;
		option.name = "APB_Functional_Coverage";

		// Track Read vs Write operations
		cp_rw: coverpoint cov_tx.rw {
			bins read  = {0};
			bins write = {1};
		}

		// Track which slave is being accessed
		cp_slave: coverpoint cov_tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] {
			bins slave0_mem   = {0};
			bins slave1_mem   = {1};
			bins slave2_timer = {2};
		}

		// Cross Coverage: Ensure every slave receives BOTH a read and a write
		cx_slave_rw: cross cp_slave, cp_rw;
	endgroup

	function new(virtual apb_external_if ext_if, mailbox mon_in2sb);
		this.vif = ext_if;
		this.mon_in2sb = mon_in2sb;
		this.prev_start = 0;
		apb_cg = new(); // Instantiate the covergroup
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
				tx.timestamp = $time;
				
				$display("[MONITOR_IN] SETUP: TX %s ADDR=0x%08x DATA=0x%08x slave=%0d", (tx.rw ? "WRITE" : "READ "), tx.addr, tx.data_in, tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len]);
				
				// Sample Functional Coverage
				cov_tx = tx;
				apb_cg.sample();

				mon_in2sb.put(tx);
			end
			prev_start = vif.start;
		end
	endtask
endclass : MONITOR_IN