class GENERATOR;
	rand TRANSACTION tx;
	mailbox gen2drv;
	int tx_count;
	int tests;
	bit end_of_tests;

	function new(mailbox gen2drv, int tests);
		this.gen2drv = gen2drv;
		this.tests = tests;
		this.end_of_tests = 0;
		this.tx_count = 0;
	endfunction

	task start();
		$display("[GENERATOR] STARTED");

		repeat (tests) begin
			tx = new();
			assert (tx.randomize()) else $fatal("Failed to randomize transaction");
			$display("[GENERATOR] Generated transaction #%0d: ADDR=0x%08x, DATA=0x%08x, RW=%b", tx_count + 1, tx.addr, tx.data_in, tx.rw);
			gen2drv.put(tx);
			tx_count++;
		end
		end_of_tests = 1;
		$display("[GENERATOR] FINISHED");
	endtask

endclass : GENERATOR