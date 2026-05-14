class apb_test extends uvm_test;
	`uvm_component_utils(apb_test)

	apb_env env;
	transaction_seq seq;

	// APB_TEST Constructor
	function new(string name = "apb_test", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_TEST", "Test constructor called", UVM_HIGH)
	endfunction

	// APB_TEST Build Phase
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("APB_TEST", "Building test environment", UVM_HIGH)

		env = apb_env::type_id::create("env", this);

	endfunction

	// APB_TEST Connect Phase
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_TEST", "Connecting test components", UVM_HIGH)
	endfunction
	
	// APB_TEST Run Phase
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		`uvm_info("APB_TEST", "RUNNING", UVM_HIGH)

		phase.raise_objection(this);
		// Test sequence
		repeat(100) begin
			seq = transaction_seq::type_id::create("transaction_seq");
			seq.start(env.agnt.seqr);
		end
		phase.drop_objection(this);
	endtask

// LOGGING

	virtual function void end_of_elaboration_phase(uvm_phase phase);
        UVM_FILE scb_file, drv_file;
        super.end_of_elaboration_phase(phase);

        // Open the files
        scb_file = $fopen("scoreboard_report.log", "w");
        drv_file = $fopen("driver_report.log", "w");

        // Scoreboard  write to file and  terminal (UVM_DISPLAY | UVM_LOG)
        // UVM_LOG to write only to file and silence the terminal
        uvm_top.set_report_id_action_hier("SCB_OUT", UVM_DISPLAY | UVM_LOG);
        uvm_top.set_report_id_file_hier("SCB_OUT", scb_file);

        uvm_top.set_report_id_action_hier("DRV_STIMULUS", UVM_DISPLAY | UVM_LOG);
        uvm_top.set_report_id_file_hier("DRV_STIMULUS", drv_file);

		uvm_top.print_topology();

		`uvm_info("APB_TEST", "End of Elaboration Phase - Topology and File Logging is set", UVM_HIGH)

    endfunction

endclass : apb_test


