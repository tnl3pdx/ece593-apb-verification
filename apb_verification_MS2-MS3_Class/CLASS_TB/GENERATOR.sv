class GENERATOR;
	mailbox gen2drv;
	int num_tests;
	int tx_count;
	event end_of_tests;

	function new(mailbox gen2drv, int num_tests);
		this.gen2drv = gen2drv;
		this.num_tests = num_tests;
		this.tx_count = 0;
	endfunction

	task start();
		TRANSACTION tx;
		$display("[GENERATOR] STARTED: Executing Directed Sequences + Random Tests");

		// =========================================================
		// SEQUENCE 1: FV-001 Reset Check
		// Sequentially read all 32 registers from Slave 0 and Slave 1
		// before any writes can corrupt them.
		// =========================================================
		for (int s = 0; s < 2; s++) begin
			for (int r = 0; r < 32; r++) begin
				tx = new();
				// Calculate exact address: slave_idx + reg_idx
				tx.addr = (s << (PARAMS::REG_NUM + PARAMS::WORD_LEN)) | (r << PARAMS::WORD_LEN);
				tx.rw = 0; // READ
				tx.data_in = 32'h0;
				gen2drv.put(tx);
				tx_count++;
			end
		end

		// =========================================================
		// SEQUENCE 2: FV-004 Data Integrity Check
		// Write specific patterns to a register, and immediately read
		// them back to hit the Write x Read cross coverage bins.
		// =========================================================
		begin
			bit [31:0] test_patterns[4] = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555};
			foreach(test_patterns[p]) begin
				for (int s = 0; s < 3; s++) begin
					// 1. Write the pattern
					tx = new();
					tx.addr = (s << (PARAMS::REG_NUM + PARAMS::WORD_LEN)); // Target Reg 0
					tx.rw = 1; // WRITE
					tx.data_in = test_patterns[p];
					gen2drv.put(tx);
					tx_count++;

					// 2. Read the pattern immediately
					tx = new();
					tx.addr = (s << (PARAMS::REG_NUM + PARAMS::WORD_LEN)); // Same Reg 0
					tx.rw = 0; // READ
					tx.data_in = 32'h0;
					gen2drv.put(tx);
					tx_count++;
				end
			end
		end

		/*
		// Generate invalid transcations 
		begin
			// Invalid Address: Targeting non-existent slave (e.g., slave index 4)
			tx = new();
			tx.addr = (4 << (PARAMS::REG_NUM + PARAMS::WORD_LEN)); // Invalid slave index
			tx.rw = 1; // WRITE
			tx.data_in = 32'hDEADBEEF;
			gen2drv.put(tx);
			tx_count++;

			// Invalid Address: Unaligned access
			tx = new();
			tx.addr = (0 << (PARAMS::REG_NUM + PARAMS::WORD_LEN)) | 2; // Slave 0, Reg 0, but unaligned
			tx.rw = 1; // WRITE
			tx.data_in = 32'hCAFEBABE;
			gen2drv.put(tx);
			tx_count++;

		end
		*/

		// =========================================================
		// SEQUENCE 3: Standard Random Testing (FV-002, FV-003)
		// Fill the remaining requested tests with random traffic.
		// =========================================================
		while (tx_count < num_tests) begin
			tx = new();
			if (!tx.randomize()) $fatal("[GENERATOR] Randomization failed!");
			gen2drv.put(tx);
			tx_count++;
		end

		-> end_of_tests;
		$display("[GENERATOR] FINISHED. Total TX: %0d", tx_count);
	endtask
endclass : GENERATOR