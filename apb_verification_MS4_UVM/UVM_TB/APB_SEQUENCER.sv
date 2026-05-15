class apb_sequencer extends uvm_sequencer #(apb_transaction);

	`uvm_component_utils(apb_sequencer)

	function new(string name, uvm_component parent);
		super.new(name, parent);
		`uvm_info("APB_SEQR", "APB Sequencer initialized", UVM_MEDIUM)
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
	endfunction

endclass : apb_sequencer