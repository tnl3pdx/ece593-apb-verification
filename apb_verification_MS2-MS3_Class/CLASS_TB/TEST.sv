module TEST #(
	parameter NUM_TESTS = 100
)
(
	apb_external_if ext_if,
	apb_bus_if bus_if
);
	
	class ENV;

		// Component instances
		GENERATOR gen;
		DRIVER drv;
		MONITOR_IN mon_in;
		MONITOR_OUT mon_out;
		SCOREBOARD sb;
		PROTOCOL_COVERAGE proto_cov;

		mailbox gen2drv;
		mailbox mon_in2sb;
		mailbox mon_out2scb;

		// Virtual interface handles
		virtual apb_external_if ext_if;
		virtual apb_bus_if #(.DATA_WIDTH(PARAMS::DATA_WIDTH), .ADDR_WIDTH(PARAMS::ADDR_WIDTH), .SLAVE_COUNT(PARAMS::SLAVE_COUNT)) bus_if;

		function new(virtual apb_external_if ext_if, virtual apb_bus_if #(.DATA_WIDTH(PARAMS::DATA_WIDTH), .ADDR_WIDTH(PARAMS::ADDR_WIDTH), .SLAVE_COUNT(PARAMS::SLAVE_COUNT)) bus_if, int tests);
			this.ext_if = ext_if;
			this.bus_if = bus_if;

			this.gen2drv = new();
			this.mon_in2sb = new();
			this.mon_out2scb = new();

			this.gen = new(gen2drv, tests);
			this.drv = new(ext_if, gen2drv);
			this.mon_in = new(ext_if, mon_in2sb);
			this.mon_out = new(ext_if, mon_out2scb);
			this.sb = new(mon_in2sb, mon_out2scb, tests);
			this.proto_cov = new(bus_if);
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
				proto_cov.start();
			join_none
		endtask

		task post_test();
			// Generate all testcases
			wait(gen.end_of_tests.triggered);
			$display("[ENV] All testcases generated. Waiting for completion...");
			// Check tx count from generator matches transactions observed by driver
			wait(gen.tx_count == drv.tx_count1);
			$display("[ENV] Generator and Driver transaction counts match: %0d transactions", gen.tx_count);
			// Check tx count from driver matches transactions observed by output monitor
			wait(drv.tx_count2 == mon_out.tx_count);
			$display("[ENV] Driver and Output Monitor transaction counts match: %0d transactions", drv.tx_count2);
			// Wait until scoreboard has processed all outputs
			wait(sb.total_output_count == gen.tx_count);
			$display("[ENV] Scoreboard has processed all transactions. Total transactions: %0d", gen.tx_count);
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
		ENV env = new(ext_if, bus_if, NUM_TESTS);
		env.run();
	end

endmodule : TEST