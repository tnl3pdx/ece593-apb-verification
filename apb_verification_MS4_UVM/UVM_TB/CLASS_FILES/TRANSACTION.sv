class apb_transaction extends uvm_sequence_item;
	
	// Field Macro Block
	// https://verificationacademy.com/verification-methodology-reference/uvm/docs_1.1c/html/files/macros/uvm_object_defines-svh.html
	// Allows for the following: clone, copy, compare, print, sprint (for strings), pack/unpack]
	// I used a combination of Google Gemini AI and verification academy to implement this, since it would
	// make the scoreboard more modular
	`uvm_object_utils_begin(apb_transaction)
		`uvm_field_int(slave_sel,       UVM_DEFAULT | UVM_DEC)
		`uvm_field_int(reg_sel,         UVM_DEFAULT | UVM_DEC)
		`uvm_field_int(data_in,         UVM_DEFAULT | UVM_HEX)
		`uvm_field_int(rw,              UVM_DEFAULT | UVM_BIN)
		`uvm_field_int(addr,            UVM_DEFAULT | UVM_HEX)
		`uvm_field_int(data_out,        UVM_DEFAULT | UVM_HEX)
		`uvm_field_int(transfer_status, UVM_DEFAULT | UVM_BIN)
		`uvm_field_int(valid,           UVM_DEFAULT | UVM_BIN)
		`uvm_field_int(timestamp,       UVM_DEFAULT | UVM_DEC)
		`uvm_field_int(illegal,         UVM_DEFAULT | UVM_BIN)
	`uvm_object_utils_end


	// Separated selection fields for cleaner constraint control
	rand bit [PARAMS::SLAVE_COUNT-1:0] slave_sel;
	rand bit [PARAMS::REG_NUM-1:0] reg_sel;
	rand bit [PARAMS::DATA_WIDTH-1:0] data_in;
	rand bit rw;

	bit [PARAMS::ADDR_WIDTH-1:0] addr;
	bit [PARAMS::DATA_WIDTH-1:0] data_out;
	bit transfer_status;
	bit valid;
	time timestamp;

	bit illegal; // Flag for transactions that violate constraints (e.g., invalid slave/reg_sel combinations)


	constraint c_slave_distribution {
		// Solver can now evenly distribute slave_sel independently
		slave_sel dist { 0 := 1, 1 := 1, 2 := 1 };
	}

	constraint c_rw {
		rw dist { 1:=1, 0:=1 }; // Even distribution of read and write transactions
	}

	constraint c_data_patterns {
		// Constrained Randomization for FV-004 Data Integrity
		data_in dist {
			32'h00000000 := 2, // Force All Zeros
			32'hFFFFFFFF := 2, // Force All Ones
			32'hAAAAAAAA := 2, // Force Alternating 1010
			32'h55555555 := 2, // Force Alternating 0101
			[32'h00000001 : 32'hFFFFFFFE] :/ 20 // Standard random values
		};
		if (!rw) data_in == 32'h0000_0000; // For reads, drive in 0s
	}

	function void post_randomize();
		// Post restrictions: Restrict timer register accesses to 0-1
		if (slave_sel == 2) begin
			reg_sel = reg_sel % PARAMS::NUM_TIMERS;
			// Restrict to valid timer registers
		end
		// Construct address from slave_sel and reg_sel
		addr = {slave_sel, reg_sel, {PARAMS::WORD_LEN{1'b0}}};
		illegal = 1'b0;
	endfunction

	// UVM Constructor
	function new(string name = "apb_transaction");
		super.new(name);
	endfunction

endclass : apb_transaction