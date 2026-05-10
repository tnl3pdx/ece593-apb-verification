class MONITOR_OUT;
	int tx_count;
	virtual apb_external_if vif;
	mailbox mon_out2scb;
	bit prev_ready;
	TRANSACTION cov_tx;

	function bit tx_is_illegal(bit [PARAMS::ADDR_WIDTH-1:0] addr);
		int unsigned slave_idx;
		int unsigned reg_idx;
		slave_idx = addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
		reg_idx = addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
		return ((addr[PARAMS::WORD_LEN-1:0] != '0) ||
				(slave_idx >= PARAMS::SLAVE_COUNT) ||
				((slave_idx == 2) && (reg_idx >= PARAMS::NUM_TIMERS)));
	endfunction

	// =========================================================
	// FV-003: APB Protocol Functional Coverage
	// =========================================================
	covergroup cg_protocol;
		option.per_instance = 1;
		option.name = "FV-003_Protocol";

		cp_rw: coverpoint cov_tx.rw {
			bins read  = {0};
			bins write = {1};
		}

		cp_error: coverpoint cov_tx.transfer_status {
			bins no_error = {0};
			bins error    = {1};
		}

		cx_type_error: cross cp_rw, cp_error {
			// Reads to our memory never generate errors, so ignore that impossible combination
			ignore_bins read_errors = binsof(cp_rw.read) && binsof(cp_error.error);
		}
	endgroup

	function new(virtual apb_external_if ext_if, mailbox mon_out2scb);
		this.vif = ext_if;
		this.mon_out2scb = mon_out2scb;
		this.tx_count = 0;
		this.prev_ready = 1;
		cg_protocol = new();
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
				tx.transfer_status = vif.transfer_status;
				tx.illegal = tx_is_illegal(vif.addr);
				tx.timestamp = $time;

				$display("[MONITOR_OUT]\tTX#%0d %s / SLAVE=%0d REG=%0d ADDR=0x%08x %0s%0s VALID=%0b TRANSFER_STATUS=%0b", 
					tx_count + 1, (tx.rw ? "WRITE" : "READ"), tx.slave_sel, tx.reg_sel, tx.addr, (tx.rw ? "" : "DATA_OUT="), (tx.rw ? "" : $sformatf("0x%08x", tx.data_out)), tx.valid, tx.transfer_status);

				// Sample Protocol Coverage
				cov_tx = tx;
				cg_protocol.sample();

				mon_out2scb.put(tx);
				tx_count++;
			end
			prev_ready = vif.ready;
		end
	endtask
endclass : MONITOR_OUT