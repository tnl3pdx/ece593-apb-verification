class MONITOR_IN;
	int tx_count;
	virtual apb_external_if vif;
	mailbox mon_in2sb;
	bit prev_start;

	function bit tx_is_illegal(bit [PARAMS::ADDR_WIDTH-1:0] addr);
		int unsigned slave_idx;
		int unsigned reg_idx;
		slave_idx = addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
		reg_idx = addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
		return ((addr[PARAMS::WORD_LEN-1:0] != '0) ||
				(slave_idx >= PARAMS::SLAVE_COUNT) ||
				((slave_idx == 2) && (reg_idx >= PARAMS::NUM_TIMERS)));
	endfunction

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
		this.tx_count = 0;
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
				tx.illegal = tx_is_illegal(vif.addr);
				tx.timestamp = $time;
				$display("[MONITOR_IN]\tTX#%0d %s / SLAVE=%0d REG=%0d ADDR=0x%08x %0s%0s", 
					tx_count + 1, (tx.rw ? "WRITE" : "READ"), tx.slave_sel, tx.reg_sel, tx.addr, (tx.rw ? "DATA_IN=" : ""), (tx.rw ? $sformatf("0x%08x", tx.data_in) : ""));
				
				// Sample Functional Coverage
				cov_tx = tx;
				apb_cg.sample();

				mon_in2sb.put(tx);
				tx_count++;
			end
			prev_start = vif.start;
		end
	endtask
endclass : MONITOR_IN