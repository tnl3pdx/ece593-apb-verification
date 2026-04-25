class TRANSACTION;
	// Inputs of transaction
	randc bit [PARAMS::ADDR_WIDTH-1:0] addr;
	rand bit [PARAMS::DATA_WIDTH-1:0] data_in;
	rand bit rw; // 1=write, 0=read

	// Outputs of transaction
	bit [PARAMS::DATA_WIDTH-1:0] data_out;
	bit valid;				// For read, indicates if data_out is valid (1) or not (0)
	bit transfer_status; 	// 0=OK, 1=ERROR

	// Constraints
	constraint addr_c { addr[1:0] == 2'b00; } // Word-aligned addresses
	constraint rw_c { rw dist { 1 := 3, 0 := 2 }; } // Writes more likely (3:2 ratio)
	constraint slave_sel_c { addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] inside {[0:PARAMS::SLAVE_COUNT-1]}; } // Slave select field, e.g. addr[31:7]
	constraint reg_c { addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM] inside {[0:(1<<PARAMS::REG_NUM)-1]}; } // Register index field, e.g. addr[6:2]
	constraint data_c { if (!rw) data_in == 32'h0000_0000; } // Don't care for read transactions}

	function new();
		this.valid = 0; // Initialize valid to 0, a read transaction will set it to 1 after generation
	endfunction

endclass : TRANSACTION

class TIMER_TRANSACTION extends TRANSACTION;
	rand bit [PARAMS::DATA_WIDTH-1:0] timer_value; // Timer-specific transaction parameter
	bit timer_status; // Timer-specific status parameter
	bit timer_start;  // Indicates if the timer should be started with this transaction

	// TODO: Create constraints for timer transactions
	// TODO: Override the new() function to set timer-specific parameters and constraints
	// TODO: Add any additional methods needed for timer transactions (determine expected status based on timer value, etc.)
endclass : TIMER_TRANSACTION

