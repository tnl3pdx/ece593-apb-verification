class apb_test extends uvm_test;
	`uvm_component_utils(apb_test)

	apb_env env;
	uvm_sequence_base seq;
	time run_timeout;
	
	// Configuration vars for test
	string test_mode = "random";
	int unsigned random_count = 20;
	int unsigned run_timeout_us = 100;
	

	// APB_TEST Constructor
	function new(string name = "apb_test", uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_TEST", "Test constructor called", UVM_HIGH)
	endfunction

	// APB_TEST Build Phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("APB_TEST", "Building test environment", UVM_HIGH)

		env = apb_env::type_id::create("env", this);

		void'($value$plusargs("APB_RUN_TIMEOUT_US=%d", run_timeout_us));
		run_timeout = run_timeout_us * 1us;
		uvm_top.set_timeout(run_timeout, 1);
		`uvm_info("APB_TEST", $sformatf("Run phase timeout set to %0t (%0d us)", run_timeout, run_timeout_us), UVM_LOW)

	endfunction

	// APB_TEST Connect Phase
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("APB_TEST", "Connecting test components", UVM_HIGH)
	endfunction
	
	// APB_TEST Run Phase
	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		`uvm_info("APB_TEST", "RUNNING", UVM_HIGH)

		void'($value$plusargs("APB_TEST_MODE=%s", test_mode));
		void'($value$plusargs("APB_RANDOM_COUNT=%d", random_count));
		if (test_mode.len() == 0) begin
			test_mode = "all";
		end

		phase.raise_objection(this);

		case (test_mode)
			"reset": begin
				seq = apb_reset_check_seq::type_id::create("apb_reset_check_seq");
				seq.start(env.agnt.seqr);
			end
			"data": begin
				seq = apb_data_integrity_seq::type_id::create("apb_data_integrity_seq");
				seq.start(env.agnt.seqr);
			end
			"stuck": begin
				seq = apb_stuck_bits_seq::type_id::create("apb_stuck_bits_seq");
				seq.start(env.agnt.seqr);
			end
			"timer": begin
				seq = apb_timer_validation_seq::type_id::create("apb_timer_validation_seq");
				seq.start(env.agnt.seqr);
			end
			"illegal": begin
				seq = apb_illegal_tx_seq::type_id::create("apb_illegal_tx_seq");
				seq.start(env.agnt.seqr);
			end
			"random": begin
				repeat (random_count) begin
					seq = rand_seq::type_id::create("rand_seq");
					seq.start(env.agnt.seqr);
				end
			end
			"all": begin
				run_directed_sequences();
				repeat (random_count) begin
					seq = rand_seq::type_id::create("rand_seq");
					seq.start(env.agnt.seqr);
				end
			end
		endcase
		phase.drop_objection(this);
	endtask

	task automatic run_directed_sequences();
		seq = apb_reset_check_seq::type_id::create("apb_reset_check_seq");
		seq.start(env.agnt.seqr);

		seq = apb_data_integrity_seq::type_id::create("apb_data_integrity_seq");
		seq.start(env.agnt.seqr);

		seq = apb_stuck_bits_seq::type_id::create("apb_stuck_bits_seq");
		seq.start(env.agnt.seqr);

		seq = apb_timer_validation_seq::type_id::create("apb_timer_validation_seq");
		seq.start(env.agnt.seqr);

		seq = apb_illegal_tx_seq::type_id::create("apb_illegal_tx_seq");
		seq.start(env.agnt.seqr);
	endtask

	virtual function void end_of_elaboration_phase(uvm_phase phase);
        UVM_FILE scb_file, trs_file;
        super.end_of_elaboration_phase(phase);

        // Open the files
        scb_file = $fopen("logs/uvm_scoreboard_report.log", "w");
        trs_file = $fopen("logs/uvm_transaction_report.log", "w");

		// Configure Scoreboard Logging
        env.scb.set_report_verbosity_level(UVM_HIGH);
		uvm_top.set_report_id_action_hier("APB_SCB_IN", UVM_LOG);
        uvm_top.set_report_id_file_hier("APB_SCB_IN", scb_file);
		uvm_top.set_report_id_action_hier("APB_SCB_OUT", UVM_LOG);
		uvm_top.set_report_id_file_hier("APB_SCB_OUT", scb_file);
		uvm_top.set_report_id_action_hier("APB_SCB", UVM_LOG | UVM_DISPLAY);
		uvm_top.set_report_id_file_hier("APB_SCB", scb_file);

		// Configure Driver and Monitor Logging
		env.agnt.drv.set_report_verbosity_level(UVM_HIGH);
        uvm_top.set_report_id_action_hier("APB_DRV", UVM_LOG);
        uvm_top.set_report_id_file_hier("APB_DRV", trs_file);

		env.agnt.mon.set_report_verbosity_level(UVM_HIGH);
		uvm_top.set_report_id_action_hier("APB_MON_IN", UVM_LOG);
		uvm_top.set_report_id_file_hier("APB_MON_IN", trs_file);

		uvm_top.set_report_id_action_hier("APB_MON_OUT", UVM_LOG);
		uvm_top.set_report_id_file_hier("APB_MON_OUT", trs_file);

		uvm_top.print_topology();

		`uvm_info("APB_TEST", "End of Elaboration Phase - Topology and File Logging is set", UVM_HIGH)

    endfunction

endclass : apb_test


