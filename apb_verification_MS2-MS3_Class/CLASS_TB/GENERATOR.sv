class GENERATOR;
	mailbox gen2drv;
	int num_tests;
	int tx_count;
	int enable_directed; // Set to 1 to enable directed sequences, 0 for purely random testing
	event end_of_tests;

	function new(mailbox gen2drv, int num_tests, int enable_directed);
		this.gen2drv = gen2drv;
		this.num_tests = num_tests;
		this.tx_count = 0;
		this.enable_directed = enable_directed;
	endfunction

	task directed_sequences(TRANSACTION tx);
		// =========================================================
		// SEQUENCE 1: FV-001 Reset Check
		// Sequentially read all 32 registers from Slave 0 and Slave 1
		// before any writes can corrupt them.
		// =========================================================
		for (int s = 0; s < 2; s++) begin
			for (int r = 0; r < 32; r++) begin
				tx = new();
				tx.slave_sel = s;
				tx.reg_sel = r;
				tx.rw = 0; // READ
				tx.data_in = 32'h0;
				tx.post_randomize(); // Build addr from slave_sel & reg_sel
				tx.illegal = 1'b0;
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
					tx.slave_sel = s;
					tx.reg_sel = 0;
					tx.rw = 1; // WRITE
					tx.data_in = test_patterns[p];
					tx.post_randomize();
					tx.illegal = 1'b0;
					gen2drv.put(tx);
					tx_count++;

					// 2. Read the pattern immediately
					tx = new();
					tx.slave_sel = s;
					tx.reg_sel = 0;
					tx.rw = 0; // READ
					tx.data_in = 32'h0;
					tx.post_randomize();
					gen2drv.put(tx);
					tx_count++;
				end
			end
		end

		// =========================================================
		// SEQUENCE 3: Timer Validation Sequences
		// =========================================================
		$display("[GENERATOR] SEQUENCE 3: Executing Timer Validation Sequences");
		
		// --- 3A. Floor at Zero Check ---
		// Write a small value (5) to Timer 0, wait for it to expire, then read.
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 0;
		tx.rw = 1; tx.data_in = 32'h00000005;
		tx.post_randomize();
		tx.illegal = 1'b0;
		gen2drv.put(tx); tx_count++;
		
		// Insert dummy reads to other slaves to pass time (> 5 cycles)
		for (int i = 0; i < 6; i++) begin
			tx = new();
			tx.slave_sel = 0;
			tx.reg_sel = 0;
			tx.rw = 0; tx.data_in = 32'h0;
			tx.post_randomize();
				tx.illegal = 1'b0;
			gen2drv.put(tx); tx_count++;
		end
		
		// Read Timer 0 back - Scoreboard should expect 0x0
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 0;
		tx.rw = 0; tx.data_in = 32'h0;
		tx.post_randomize();
		tx.illegal = 1'b0;
		gen2drv.put(tx); tx_count++;

		// --- 3B. Mid-Countdown Override Check ---
		// Write a large value to Timer 1, then immediately overwrite it.
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 1;
		tx.rw = 1; tx.data_in = 32'h00000FFF; // Initial large value
		tx.post_randomize();
		tx.illegal = 1'b0;
		gen2drv.put(tx); tx_count++;
		
		// Read to advance time slightly
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 1;
		tx.rw = 0; tx.data_in = 32'h0;
		tx.post_randomize();
		tx.illegal = 1'b0;
		gen2drv.put(tx); tx_count++;
		
		// Overwrite while still counting
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 1;
		tx.rw = 1; tx.data_in = 32'h000000AA; // New value
		tx.post_randomize();
		tx.illegal = 1'b0;
		gen2drv.put(tx); tx_count++;

		// --- 3C. Out-of-Bounds Indexing Check ---
		// Attempt to write and read a timer register outside the valid range.
		// This bypasses TRANSACTION::post_randomize() so the address stays invalid.
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = PARAMS::NUM_TIMERS;
		tx.rw = 1;
		tx.data_in = 32'hDEADBEEF;
		tx.addr = {tx.slave_sel, tx.reg_sel, {PARAMS::WORD_LEN{1'b0}}};
		tx.illegal = 1'b1;
		gen2drv.put(tx); tx_count++;
		
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = PARAMS::NUM_TIMERS;
		tx.rw = 0;
		tx.data_in = 32'h0;
		tx.addr = {tx.slave_sel, tx.reg_sel, {PARAMS::WORD_LEN{1'b0}}};
		tx.illegal = 1'b1;
		gen2drv.put(tx); tx_count++;

		// --- 3D. Invalid Slave Selection Check ---
		// Target a slave index outside the configured slave range.
		tx = new();
		tx.slave_sel = PARAMS::SLAVE_COUNT;
		tx.reg_sel = 0;
		tx.rw = 1;
		tx.data_in = 32'hCAFEBABE;
		tx.addr = {tx.slave_sel, tx.reg_sel, {PARAMS::WORD_LEN{1'b0}}};
		tx.illegal = 1'b1;
		gen2drv.put(tx); tx_count++;

		// --- 3E. Unaligned Access Check ---
		// Keep the address structure valid, but break word alignment.
		tx = new();
		tx.slave_sel = 2;
		tx.reg_sel = 0;
		tx.rw = 1;
		tx.data_in = 32'hFACE_FEED;
		tx.addr = {tx.slave_sel, tx.reg_sel, {PARAMS::WORD_LEN{1'b0}}} | {{PARAMS::ADDR_WIDTH-2{1'b0}}, 2'b10};
		tx.illegal = 1'b1;
		gen2drv.put(tx); tx_count++;

		$display("[GENERATOR] COMPLETED DIRECTED SEQUENCES. Total TX: %0d", tx_count);

	endtask

	task start();
		TRANSACTION tx;
		$display("[GENERATOR] STARTED: Executing Tests");

		if (enable_directed) begin
			$display("[GENERATOR] Starting Directed Sequences...");
			directed_sequences(tx);
		end

		// =========================================================
		// Standard Random Testing (FV-002, FV-003)
		// Fill the remaining requested tests with random traffic.
		// =========================================================
		$display("[GENERATOR] Starting Random Sequences...");
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