class apb_sequencer extends uvm_sequencer #(apb_transaction);

	`uvm_component_utils(apb_sequencer)

	function new(string name, uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_SEQR", "APB Sequencer initialized", UVM_MEDIUM)
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask

endclass : apb_sequencer