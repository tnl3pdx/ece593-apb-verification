class apb_monitor extends uvm_monitor;
	`uvm_component_utils(apb_monitor)

	virtual apb_external_if vif;
	uvm_analysis_port #(apb_transaction) monitor_port;

	int tx_count_in;
	int tx_count_out;
	bit prev_start;
	bit prev_ready;

	apb_transaction cov_in_tx;
	apb_transaction cov_out_tx;

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
	// FV-006 Functional Coverage Model
	// =========================================================
	covergroup cg_apb;
		option.per_instance = 1;
		option.name = "APB_Functional_Coverage";

		// Track Read vs Write operations
		cp_rw: coverpoint cov_in_tx.rw {
			bins read  = {0};
			bins write = {1};
		}

		// Track which slave is being accessed
		cp_slave: coverpoint cov_in_tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] {
			bins slave0_mem   = {0};
			bins slave1_mem   = {1};
			bins slave2_timer = {2};
		}

		// Cross Coverage: Ensure every slave receives BOTH a read and a write
		cx_slave_rw: cross cp_slave, cp_rw;
	endgroup

	// =========================================================
	// FV-003: APB Protocol Functional Coverage
	// =========================================================
	covergroup cg_protocol;
		option.per_instance = 1;
		option.name = "FV-003_Protocol";

		cp_rw: coverpoint cov_out_tx.rw {
			bins read  = {0};
			bins write = {1};
		}

		cp_error: coverpoint cov_out_tx.transfer_status {
			bins no_error = {0};
			bins error    = {1};
		}

		cx_type_error: cross cp_rw, cp_error {
			// Reads to our memory never generate errors, so ignore that impossible combination
			ignore_bins read_errors = binsof(cp_rw.read) && binsof(cp_error.error);
		}
	endgroup

	function new(string name = "apb_monitor", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_MONITOR", "Creating APB Monitor", UVM_HIGH)

		// Initialize transaction counts and previous signal states
		tx_count_in = 0;
		tx_count_out = 0;
		prev_start = 1'b0;
		prev_ready = 1'b1;

		// Initialize coverage transactions and covergroups

		cg_apb = new();
		cg_protocol = new();
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		monitor_port = new("monitor_port", this);

		if (!uvm_config_db#(virtual apb_external_if)::get(this, "*", "vif", vif)) begin
			`uvm_error("APB_MONITOR", "Failed to get VIF from config DB.")
		end

	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_MONITOR", "Connecting monitor to scoreboard", UVM_HIGH)
	endfunction

	virtual task run_phase(uvm_phase phase);
		`uvm_info("APB_MONITOR", "STARTED", UVM_HIGH)
		fork
			monitor_input();
			monitor_output();
		join
	endtask

	task monitor_input();
		apb_transaction tx;
		int unsigned slave_idx;
		int unsigned reg_idx;
		forever begin
			@(posedge vif.clk);
			if (vif.start && !prev_start) begin
				tx = apb_transaction::type_id::create("tx_in", this);
				
				// Capture transaction details
				tx.addr = vif.addr;
				tx.data_in = vif.data_in;
				tx.rw = vif.rw;
				tx.illegal = tx_is_illegal(vif.addr);
				tx.timestamp = $time;

				// Decode slave and register indices for coverage and reporting
				slave_idx = vif.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
				reg_idx = vif.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
				tx.slave_sel = slave_idx;
				tx.reg_sel = reg_idx;

				`uvm_info("MONITOR_IN", $sformatf(
					"TX#%0d %s / SLAVE=%0d REG=%0d ADDR=0x%08x %s%s",
					tx_count_in + 1,
					(tx.rw ? "WRITE" : "READ"),
					slave_idx,
					reg_idx,
					tx.addr,
					(tx.rw ? "DATA_IN=" : ""),
					(tx.rw ? $sformatf("0x%08x", tx.data_in) : "")
				), UVM_LOW)

				// Update coverage transaction for input covergroup
				cov_in_tx = tx;
				cg_apb.sample();

				// Send transaction to scoreboard via analysis port
				monitor_port.write(tx);
				tx_count_in++;
			end
			prev_start = vif.start;
		end
	endtask

	task monitor_output();
		apb_transaction tx;
		int unsigned slave_idx;
		int unsigned reg_idx;
		forever begin
			@(posedge vif.clk);
			if (vif.ready && !prev_ready) begin
				tx = apb_transaction::type_id::create("tx_out", this);
				
				// Capture transaction details
				tx.addr = vif.addr;
				tx.data_out = vif.data_out;
				tx.rw = vif.rw;
				tx.valid = vif.valid;
				tx.transfer_status = vif.transfer_status;
				tx.illegal = tx_is_illegal(vif.addr);
				tx.timestamp = $time;

				// Decode slave and register indices for coverage and reporting
				slave_idx = vif.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
				reg_idx = vif.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
				tx.slave_sel = slave_idx;
				tx.reg_sel = reg_idx;

				`uvm_info("MONITOR_OUT", $sformatf(
					"TX#%0d %s / SLAVE=%0d REG=%0d ADDR=0x%08x %s%s VALID=%0b TRANSFER_STATUS=%0b",
					tx_count_out + 1,
					(tx.rw ? "WRITE" : "READ"),
					slave_idx,
					reg_idx,
					tx.addr,
					(tx.rw ? "" : "DATA_OUT="),
					(tx.rw ? "" : $sformatf("0x%08x", tx.data_out)),
					tx.valid,
					tx.transfer_status
				), UVM_LOW)

				// Update coverage transaction for protocol covergroup
				cov_out_tx = tx;
				cg_protocol.sample();

				// Send transaction to scoreboard via analysis port
				monitor_port.write(tx);
				tx_count_out++;
			end
			prev_ready = vif.ready;
		end
	endtask

endclass : apb_monitor


