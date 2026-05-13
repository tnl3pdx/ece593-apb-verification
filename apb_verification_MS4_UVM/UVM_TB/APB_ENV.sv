class apb_env extends uvm_env;
	`uvm_component_utils(apb_env)

	// Agent and scoreboard instances
	apb_agent agnt;
	apb_scoreboard scb;

	// Constructor
	function new(string name = "apb_env", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_ENV", "Environment constructor called", UVM_HIGH)
	endfunction

	// Build phase: Instantiate components
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Instantiate agent and scoreboard
		agnt = apb_agent::type_id::create("agnt", this);
		scb = apb_scoreboard::type_id::create("scb", this);
		
	endfunction

	// Connect phase: Connect agent's sequencer to the scoreboard
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_ENV", "Connecting agent to scoreboard", UVM_HIGH)

		// Connect monitor analysis ports to scoreboard exports
		agnt.mon.ap_in.connect(scb.mon_in_export);
		agnt.mon.ap_out.connect(scb.mon_out_export);
	endfunction

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask

endclass : apb_env