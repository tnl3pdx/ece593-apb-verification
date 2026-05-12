class apb_env extend uvm_env;
	`uvm_component_utils(apb_env)

	// Agent and scoreboard instances
	apb_agnt agnt;
	apb_scb scb;

	// Constructor
	function new(string name = "apb_env", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_ENV", "Environment constructor called", UVM_HIGH)
	endfunction

	// Build phase: Instantiate components and connect virtual interface
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Check for virtual interface connection
		if (!uvm_config_db#(apb_external_if)::get(this, "", "vif", vif)) begin
			`uvm_fatal("APB_ENV", "Virtual interface not found! Ensure it is set in the testbench.")
		end

		// Instantiate agent and scoreboard
		agnt = apb_agnt::type_id::create("agnt", this);
		scb = apb_scb::type_id::create("scb", this);
		
	endfunction

	// Connect phase: Connect agent's sequencer to the scoreboard
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_ENV", "Connecting agent to scoreboard", UVM_HIGH)

		// Connect export of monitor to scoreboard analysis port
		agnt.mon.monitor_port.connect(scb.scoreboard_port);
	endfunction

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask

endclass : apb_env