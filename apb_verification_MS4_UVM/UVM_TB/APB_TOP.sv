timescale 1ns/1ns

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "PARAMS.sv"
`include "APB_SEQUENCE.sv"
`include "APB_SEQUENCER.sv"
`include "APB_DRIVER.sv"
`include "APB_MONITOR.sv"
`include "APB_AGENT.sv"
`include "APB_SCOREBOARD.sv"
`include "APB_ENV.sv"
`include "APB_TEST.sv"

module apb_top;
    // Clock and Reset Signals
    logic pclk, prstn;

	// Reset and clock generation
    initial begin
        prstn = 1; // Release reset
        @(posedge pclk)
        prstn = 0;
        @(posedge pclk)
        prstn = 1; // Release reset
        @(posedge pclk);
    end
    
    initial begin
        pclk = 0;
        forever #(PARAMS::CLK_PERIOD/2) pclk = ~pclk;
    end

	// Instantiate the APB interface
	apb_external_if ext_if(.clk(pclk), .rst_n(prstn));

	// DUV instantiation
    APB_SYS_DUT #(
        .DATA_WIDTH(PARAMS::DATA_WIDTH),
        .ADDR_WIDTH(PARAMS::ADDR_WIDTH),
        .REG_NUM(PARAMS::REG_NUM),
        .MASTER_COUNT(PARAMS::MASTER_COUNT),
        .SLAVE_COUNT(PARAMS::SLAVE_COUNT),
        .WAIT_WRITE_S0(PARAMS::WAIT_WRITE_S0),
        .WAIT_READ_S0(PARAMS::WAIT_READ_S0),
        .WAIT_WRITE_S1(PARAMS::WAIT_WRITE_S1),
        .WAIT_READ_S1(PARAMS::WAIT_READ_S1),
        .WAIT_WRITE_S2(PARAMS::WAIT_WRITE_S2),
        .WAIT_READ_S2(PARAMS::WAIT_READ_S2),
        .NUM_TIMERS(PARAMS::NUM_TIMERS)
    ) apb_sys (
        .ext_if(ext_if)
    );

	// Interface Configuration for UVM components
	initial begin
		// Set the virtual interface for UVM components
		uvm_config_db#(virtual apb_external_if)::set(null, "*", "vif", ext_if);
	end

	// Test Start
	initial begin
		// Run the UVM test
		run_test("apb_test");
	end

	// Max simulation time
	initial begin
		#100000; // Set a maximum simulation time to prevent infinite runs
		$display("Maximum simulation time reached. Ending simulation.");
		$finish;
	end

	initial
		$fsdbDumpvars();

endmodule : apb_top