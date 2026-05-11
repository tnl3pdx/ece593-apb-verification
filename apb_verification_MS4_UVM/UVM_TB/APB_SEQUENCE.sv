/* UVM_SEQUENCES.sv
	This holds the classes used for the sequences in the UVM testbench
		- Base Sequence Class
		- APB Write Sequence
		- APB Read Sequence
*/

class transaction_seq extends uvm_sequence;

	`uvm_object_utils(transaction_seq)

	apb_transaction tx;

	function new(string name = "transaction_seq");
		super.new(name);
		`uvm_info("TRANSACTION_SEQUENCE", "Sequence created", UVM_HIGH);
	endfunction

	task body();
		tx = apb_transaction::type_id::create("tx");
		assert(tx.randomize()) else $fatal(1, "[SEQUENCE] Failed to randomize transaction");
		start_item(tx);
		finish_item(tx);
	endtask

endclass : transaction_seq