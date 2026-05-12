class apb_agent extends uvm_agent;
	`uvm_component_utils(apb_agent)

	// Driver, sequencer, and monitor instances
	apb_driver drv;
	apb_sequencer seqr;
	apb_monitor mon;


	function new(string name = "apb_agent", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_AGENT", "Creating APB Agent", UVM_HIGH)
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		`uvm_info("APB_AGENT", "Building agent components", UVM_HIGH)

		seqr = apb_sequencer::type_id::create("seqr", this);
		drv = apb_driver::type_id::create("drv", this);
		mon = apb_monitor::type_id::create("mon", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_AGENT", "Connecting driver and monitor to sequencer and scoreboard", UVM_HIGH)

		drv.seq_item_port.connect(seqr.seq_item_export);
	endfunction

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask

endclass : apb_agent