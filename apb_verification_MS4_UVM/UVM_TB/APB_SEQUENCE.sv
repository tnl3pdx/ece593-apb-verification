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
		`uvm_info("TRANSACTION_SEQUENCE", "Sequence created", UVM_HIGH)
	endfunction

	task body();
		tx = apb_transaction::type_id::create("tx");
		assert(tx.randomize()) else $fatal(1, "[SEQUENCE] Failed to randomize transaction");
		start_item(tx);
		finish_item(tx);
	endtask

endclass : transaction_seq

//DIRECT TESTS

class apb_directed_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_directed_seq)

    function new(string name = "apb_directed_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction tx;
        `uvm_info("DIR_SEQ", "Starting Directed Sequence...", UVM_LOW)

        // Example: Directed Write to Slave 1, Reg 0 with specific data
        tx = apb_transaction::type_id::create("tx");
        start_item(tx);
        // Use randomize() & 'with' constraints to force specific values
        assert(tx.randomize() with {
            rw == 1;
            slave_sel == 1;
            reg_sel == 0;
            data_in == 32'hDEADBEEF;
        }) else `uvm_fatal("DIR_SEQ", "Randomization failed")
        finish_item(tx);

        // Example: Follow-up Directed Read from the same register
        tx = apb_transaction::type_id::create("tx");
        start_item(tx);
        assert(tx.randomize() with {
            rw == 0;
            slave_sel == 1;
            reg_sel == 0;
        }) else `uvm_fatal("DIR_SEQ", "Randomization failed")
        finish_item(tx);

        `uvm_info("DIR_SEQ", "Directed Sequence Complete.", UVM_LOW)
    endtask
endclass