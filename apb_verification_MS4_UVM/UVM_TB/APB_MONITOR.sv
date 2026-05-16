class apb_monitor extends uvm_monitor;
	`uvm_component_utils(apb_monitor)

	virtual apb_external_if vif;
	uvm_analysis_port #(apb_transaction) ap_in;
	uvm_analysis_port #(apb_transaction) ap_out;

	int tx_count_in;
	int tx_count_out;
	bit prev_start;
	bit prev_ready;

	function bit tx_is_illegal(bit [PARAMS::ADDR_WIDTH-1:0] addr);
		int unsigned slave_idx;
		int unsigned reg_idx;
		slave_idx = PARAMS::addr_to_slave_idx(addr);
		reg_idx = PARAMS::addr_to_reg_idx(addr);
		return ((addr[PARAMS::WORD_LEN-1:0] != '0) ||
				(slave_idx >= PARAMS::SLAVE_COUNT) ||
				((slave_idx == 2) && (reg_idx >= PARAMS::NUM_TIMERS)));
	endfunction

	function new(string name = "apb_monitor", uvm_component parent);
		super.new(name, parent);

		// Initialize transaction counts and previous signal states
		tx_count_in = 0;
		tx_count_out = 0;
		prev_start = 1'b0;
		prev_ready = 1'b1;
	
		`uvm_info("APB_MON", "APB Monitor initialized", UVM_MEDIUM)
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		`uvm_info("APB_MON", "Building APB Monitor components (initialize ports and check VIF)", UVM_MEDIUM)

		ap_in = new("ap_in", this);
		ap_out = new("ap_out", this);

		if (!uvm_config_db#(virtual apb_external_if)::get(this, "*", "vif", vif)) begin
			`uvm_error("APB_MON", "Failed to get VIF from config DB.")
		end
		`uvm_info("APB_MON", "Ports initialized and VIF present", UVM_MEDIUM)
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
	
        `uvm_info("APB_MON", "Run phase started. Waiting for reset...", UVM_MEDIUM)

        // Wait for reset sequence to complete before starting monitoring
        wait(vif.rst_n === 1'b1);
		wait (vif.rst_n === 1'b0);
        wait (vif.rst_n === 1'b1);
        @(posedge vif.clk);

        `uvm_info("APB_MON", "Reset complete. Starting capture threads...", UVM_MEDIUM)
        fork
            monitor_input();
            monitor_output();
        join
    endtask

	task monitor_input();
		apb_transaction tx;
		int unsigned slave_idx;
		int unsigned reg_idx;
		string data_str;
		string monitor_msg;
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
				slave_idx = PARAMS::addr_to_slave_idx(vif.addr);
				reg_idx = PARAMS::addr_to_reg_idx(vif.addr);
				tx.slave_sel = slave_idx;
				tx.reg_sel = reg_idx;

				if (tx.rw) begin
					data_str = $sformatf("0x%08x", tx.data_in);
				end else begin
					data_str = "N/A";
				end
				monitor_msg = $sformatf(
					"\nTX#%0d\n  Type: %s\n  Slave: %0d\n  Reg: %0d\n  Addr: 0x%08x\n  Data: %s\n  Illegal: %0b",
					tx_count_in + 1,
					(tx.rw ? "WRITE" : "READ"),
					slave_idx,
					reg_idx,
					tx.addr,
					data_str,
					tx.illegal
				);
				`uvm_info("APB_MON_IN", monitor_msg, UVM_HIGH)

				// Send transaction to scoreboard via analysis port
				ap_in.write(tx);
				tx_count_in++;
			end
			prev_start = vif.start;
		end
	endtask

	task monitor_output();
		apb_transaction tx;
		int unsigned slave_idx;
		int unsigned reg_idx;
		string data_str;
		string monitor_msg;
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
				slave_idx = PARAMS::addr_to_slave_idx(vif.addr);
				reg_idx = PARAMS::addr_to_reg_idx(vif.addr);
				tx.slave_sel = slave_idx;
				tx.reg_sel = reg_idx;

				if (tx.rw) begin
					data_str = "N/A";
				end else begin
					data_str = $sformatf("0x%08x", tx.data_out);
				end
				monitor_msg = $sformatf(
					"\nTX#%0d\n  Type: %s\n  Slave: %0d\n  Reg: %0d\n  Addr: 0x%08x\n  Data: %s\n  Valid: %0b\n  Transfer Status: %0b",
					tx_count_out + 1,
					(tx.rw ? "WRITE" : "READ"),
					slave_idx,
					reg_idx,
					tx.addr,
					data_str,
					tx.valid,
					tx.transfer_status
				);
				`uvm_info("APB_MON_OUT", monitor_msg, UVM_HIGH)

				// Send transaction to scoreboard via analysis port
				ap_out.write(tx);
				tx_count_out++;
			end
			prev_ready = vif.ready;
		end
	endtask

endclass : apb_monitor


