class GENERATOR;
	localparam int enable_directed = 0; // Set to 1 to enable directed sequences, 0 for purely random testing

	mailbox gen2drv;
	int num_tests;
	int tx_count;
	event end_of_tests;

	function new(mailbox gen2drv, int num_tests);
		this.gen2drv = gen2drv;
		this.num_tests = num_tests;
		this.tx_count = 0;
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
	endtask

	task start();
		TRANSACTION tx, chained_tx;
		int remaining;
		$display("[GENERATOR] STARTED: Executing Directed Sequences + Random Tests");

		if (enable_directed) begin
			$display("[GENERATOR] Starting Directed Sequences...");
			directed_sequences(tx);
		end

		// =========================================================
		// Standard Random Testing (FV-002, FV-003)
		// Fill the remaining requested tests with random traffic.
		// =========================================================
		while (tx_count < num_tests) begin
			tx = new();
			if (!tx.randomize()) $fatal("[GENERATOR] Randomization failed!");

			// Chaining Flow: If transaction is a chain, generate additional transactions.
			if (tx.chain_en == 1) begin
				$display("[GENERATOR] Generated a chain of length %0d for slave %0d", tx.chain_length, tx.slave_sel);
				// Enqueue the head transaction first so the driver receives the chain start
				gen2drv.put(tx);
				tx_count++;

				// Generate and enqueue the remaining chained transactions
				remaining = tx.chain_length; // remaining includes head
				while (remaining > 1) begin
					if (tx_count >= num_tests) begin
						break; 		// Don't exceed total test count
					end
					chained_tx = new();
					chained_tx.slave_sel.rand_mode(0); 		// Disable randomization for slave_sel
					chained_tx.chain_length.rand_mode(0); 	// Disable randomization for chain_length
					chained_tx.slave_sel = tx.slave_sel;    // Assign the same slave_sel for chaining
					chained_tx.chain_length = remaining;    // Propagate remaining length for visibility (optional)
					if (!chained_tx.randomize()) $fatal("[GENERATOR] Randomization failed for chained transaction!");

					gen2drv.put(chained_tx);
					remaining--; // one less chained transaction to generate
					tx_count++;
				end
			// If not a chain, just send the single transaction
			end else begin
				gen2drv.put(tx);
				tx_count++;
			end
		end

		-> end_of_tests;
		$display("[GENERATOR] FINISHED. Total TX: %0d", tx_count);
	endtask

	


endclass : GENERATOR