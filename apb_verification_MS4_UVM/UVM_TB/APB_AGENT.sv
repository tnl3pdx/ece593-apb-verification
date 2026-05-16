class apb_agent extends uvm_agent;
	`uvm_component_utils(apb_agent)

	// Driver, sequencer, and monitor instances
	apb_driver drv;
	apb_sequencer seqr;
	apb_monitor mon;


	function new(string name = "apb_agent", uvm_component parent);
		super.new(name, parent);

		`uvm_info("APB_AGENT", "APB Agent initialized", UVM_MEDIUM)

	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		`uvm_info("APB_AGENT", "Building agent components", UVM_MEDIUM)

		seqr = apb_sequencer::type_id::create("seqr", this);
		drv = apb_driver::type_id::create("drv", this);
		mon = apb_monitor::type_id::create("mon", this);

		`uvm_info("APB_AGENT", "Built sequencer, driver, and monitor", UVM_MEDIUM)
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		`uvm_info("APB_AGENT", "Connecting sequencer to driver", UVM_MEDIUM)

		drv.seq_item_port.connect(seqr.seq_item_export);

		`uvm_info("APB_AGENT", "Sequencer connected to driver", UVM_MEDIUM)
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask

endclass : apb_agent