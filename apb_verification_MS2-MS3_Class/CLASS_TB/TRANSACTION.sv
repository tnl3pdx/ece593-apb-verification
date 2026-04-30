class TRANSACTION;
	localparam int NUM_CHAINS = 5; // Max number of transactions in a chain

	// General Properties
	bit [PARAMS::ADDR_WIDTH-1:0] addr;
	rand bit [PARAMS::SLAVE_COUNT-1:0] slave_sel;
	rand bit [PARAMS::REG_NUM-1:0] reg_sel;
	rand bit [PARAMS::DATA_WIDTH-1:0] data_in;
	rand bit rw;

	bit [PARAMS::DATA_WIDTH-1:0] data_out;
	bit transfer_status;
	bit valid;

	// Timer Specific Properties
	rand bit [PARAMS::DATA_WIDTH-1:0] timer_value; // Timer-specific transaction parameter
	bit timer_status; // Timer-specific status parameter
	bit timer_start;  // Indicates if the timer should be started with this transaction

	// Chaining-related Properties
	rand bit [2:0] chain_length; // Number of transactions in the chain (1 means no chaining)
	bit chain_en;

	// Post-randomization variables
	function void post_randomize();
		addr = {slave_sel, reg_sel, 2'b00}; // Combine slave and register selection into the address

		if (PARAMS::PERIPH_TYPE[slave_sel] == PARAMS::TYPE_TIMER) begin
			// Ensure that chain-length is set to 1 (no chaining for timer)
			chain_length = 1;
		end

		if (chain_length > 1) begin
			chain_en = 1;
		end else begin
			chain_en = 0;
		end


	endfunction


	// --- Constraints ---

	// Ensure the randomized slave and register selections are valid
	constraint c_valid_slave_sel {
		slave_sel inside {[0 : PARAMS::SLAVE_COUNT-1]};
	}

	constraint c_valid_reg_sel {
		(slave_sel == 2) -> (reg_sel inside {0, 1});
	}

	constraint c_rw {
		rw dist { 1:=2, 0:=1 }; // More writes than reads to increase coverage of write operations
	}

	// Constrained Randomization for FV-004 Data Integrity
	constraint c_data_patterns {
		data_in dist {
			32'h00000000 := 2, // Force All Zeros
			32'hFFFFFFFF := 2, // Force All Ones
			32'hAAAAAAAA := 2, // Force Alternating 1010
			32'h55555555 := 2, // Force Alternating 0101
			[32'h00000001 : 32'hFFFFFFFE] :/ 20 // Standard random values
		};
		if (!rw) data_in == 32'h0000_0000; // For reads, drive in 0s
	}

	// Contraints for Chaining
	constraint c_chain_length {
		//chain_length dist {1:=5, [2:NUM_CHAINS] := 1}; // 5 times more likely to have single transactions than chains
		chain_length inside {[1:NUM_CHAINS]}; // Only generate chains for testing
	}


endclass : TRANSACTION

