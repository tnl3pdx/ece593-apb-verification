module TEST #(
	parameter NUM_TESTS = 100
)
(
	apb_external_if ext_if
);
	
	class ENV;

		// Component instances
		GENERATOR gen;
		DRIVER drv;
		MONITOR_IN mon_in;
		MONITOR_OUT mon_out;
		SCOREBOARD sb;

		mailbox gen2drv;
		mailbox mon_in2sb;
		mailbox mon_out2scb;

		// Virtual interface handle
		virtual apb_external_if ext_if;

		function new(virtual apb_external_if ext_if, int tests);
			this.ext_if = ext_if;

			this.gen2drv = new();
			this.mon_in2sb = new();
			this.mon_out2scb = new();

			this.gen = new(gen2drv, tests);
			this.drv = new(ext_if, gen2drv);
			this.mon_in = new(ext_if, mon_in2sb);
			this.mon_out = new(ext_if, mon_out2scb);
			this.sb = new(mon_in2sb, mon_out2scb, tests);
		endfunction


		task pre_test();
			drv.reset();
		endtask

		task test();
			// Start generator and monitors
			fork
				gen.start();
				drv.start();
				mon_in.start();
				mon_out.start();
				sb.start();
			join_none
		endtask

		task post_test();
			// Generate all testcases
			wait(gen.end_of_tests);
			// Check tx count from generator matches transactions observed by driver
			wait(gen.tx_count == drv.tx_count1);
			// Check tx count from driver matches transactions observed by output monitor
			wait(drv.tx_count2 == mon_out.tx_count);
			// Wait until scoreboard has processed all outputs
			wait(sb.total_output_count == gen.tx_count);
		endtask

		task run();
			pre_test();
			test();
			post_test();
			sb.report();
			$display("All tests completed. Final Score: %0d/%0d", sb.get_score(), gen.tx_count);
			$finish;
		endtask
	endclass

	initial begin
		ENV env = new(ext_if, NUM_TESTS);
		env.run();
	end

endmodule : TEST
