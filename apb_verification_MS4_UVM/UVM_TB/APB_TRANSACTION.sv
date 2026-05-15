class apb_transaction extends uvm_sequence_item;
	`uvm_object_utils(apb_transaction)

	// --- Properties ---

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
	bit timer_override; // Flag indicating timer override detected during write (for coverage)

	static function bit [PARAMS::ADDR_WIDTH-1:0] build_addr(
		bit [PARAMS::SLAVE_COUNT-1:0] slave_sel,
		bit [PARAMS::REG_NUM-1:0] reg_sel
	);
		bit [PARAMS::ADDR_WIDTH-1:0] addr;

		addr = '0;
		addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] = slave_sel;
		addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM] = reg_sel;
		return addr;
	endfunction

	// --- Constraints ---

	constraint c_slave_distribution {
		// Solver can now evenly distribute slave_sel independently
		slave_sel dist { 0 := 1, 1 := 1, 2 := 1 };
	}

	constraint c_rw {
		rw dist { 1:=1, 0:=1 };
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
	}

	// --- Methods ---

	function void post_randomize();
		// Post restrictions: Restrict timer register accesses to 0-1
		if (slave_sel == 2) begin
			reg_sel = reg_sel % PARAMS::NUM_TIMERS; // Restrict to valid timer registers
		end

		// Construct address from slave_sel and reg_sel using the monitored bus layout
		addr = build_addr(slave_sel, reg_sel);

		// Set illegal flag to 0 by default
		illegal = 1'b0;

		// For reads, drive in 0s
		if (!rw) data_in = 32'h0000_0000; 

	endfunction

	// UVM Constructor
	function new(string name = "apb_transaction");
		super.new(name);
	endfunction

endclass : apb_transaction

