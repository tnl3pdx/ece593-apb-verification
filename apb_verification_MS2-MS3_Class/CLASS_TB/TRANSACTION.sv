class TRANSACTION;
	// General Properties
	rand bit [PARAMS::ADDR_WIDTH-1:0] addr;
	rand bit [PARAMS::DATA_WIDTH-1:0] data_in;
	rand bit rw;

	bit [PARAMS::DATA_WIDTH-1:0] data_out;
	bit transfer_status;
	bit valid;

	// Timer Specific Properties
	rand bit [PARAMS::DATA_WIDTH-1:0] timer_value; // Timer-specific transaction parameter
	bit timer_status; // Timer-specific status parameter
	bit timer_start;  // Indicates if the timer should be started with this transaction

	bit illegal_transaction; // Flag to indicate if the transaction is illegal (e.g., invalid address)

	// Ensure the random address targets a valid slave and is word-aligned
	constraint c_valid_addr {
		(addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] == 2) -> 
			(addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM] inside {0, 1});

		addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] inside {[0 : PARAMS::SLAVE_COUNT-1]}; // Slave selection bits
		addr[1:0] == 2'b00; // Word aligned for 32-bit bus
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
endclass : TRANSACTION

