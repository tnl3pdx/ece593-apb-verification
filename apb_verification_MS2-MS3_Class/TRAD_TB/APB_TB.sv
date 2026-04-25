module APB_TB;

`timescale 1ns/100ps

//Parameters
parameter DATA_WIDTH = 32;                                           //Data bus width
parameter ADDR_WIDTH = 32;                                           //Address bus width
parameter REG_NUM = 5;                                               //Number of registers within a slave equals 2^REG_NUM. Address span within a given slave equals 2**REG_NUM [REG_NUM-1:0]
parameter MASTER_COUNT = 1;                                          //Maximum allowed number of masters
parameter SLAVE_COUNT=2;                                             //Number of slaves on the bus

localparam WORD_LEN = $clog2(DATA_WIDTH>>3);                         //Number of bits requried to specify a given byte within a word. Example: for 32-bit word 2 bits are needed for byte0-byte3. These are the LSBs of the address which are zeros in normal operation (access is word-based)
localparam ADDR_MSB_len = ADDR_WIDTH-WORD_LEN-REG_NUM;               //Part of the address bus used to select a slave unit. Address span for the salves equals 2**ADDR_MSB_len-1 

parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_0 = 0;                       //Address of slave_0
parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_1= 1;                        //Address of slave_1

// Input Signals
logic pclk, prstn;
logic start, rw;
logic [DATA_WIDTH-1:0] 		d_in;
logic [REG_NUM-1:0]			addr_in;
logic [ADDR_MSB_len-1:0] 	slave_in;

// Output Signals
logic [DATA_WIDTH-1:0]		d_out;
logic t_status;
logic valid; 
logic ready;

// Additional Signals
logic [ADDR_WIDTH-1:0]		full_addr;

// External DUT interface
apb_external_if ext_if(.clk(pclk), .rst_n(prstn));

assign full_addr = {slave_in, addr_in, {WORD_LEN{1'b0}}};

// Drive DUT through interface
assign ext_if.start = start;
assign ext_if.rw = rw;
assign ext_if.data_in = d_in;
assign ext_if.addr = full_addr;

// Observe DUT through interface
assign d_out = ext_if.data_out;
assign t_status = ext_if.transfer_status;
assign valid = ext_if.valid;
assign ready = ext_if.ready;

// DUT Instantiation with configurable waitstates
// Slave 0: 2 read waitstates, 1 write waitstate
// Slave 1: 1 read waitstate, 0 write waitstates
APB_SYS_DUT #(
	.DATA_WIDTH(DATA_WIDTH),
	.ADDR_WIDTH(ADDR_WIDTH),
	.REG_NUM(REG_NUM),
	.MASTER_COUNT(MASTER_COUNT),
	.SLAVE_COUNT(SLAVE_COUNT),
	.WAIT_WRITE_S0(1),
	.WAIT_READ_S0(2),
	.WAIT_WRITE_S1(0),
	.WAIT_READ_S1(1)
) apb_sys (
	.ext_if(ext_if)
);

// Clock generation
initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
end

initial begin
	// Reset DUT
	resetDUT();

	// ===================================================================
	// SECTION 1: Basic Functionality Tests (no waitstates)
	// ===================================================================
	$display("\n=== Basic Read/Write Tests  ===");
	$display("(Slave 0: WAIT_READ=2, WAIT_WRITE=1)\n(Slave 1: WAIT_READ=1, WAIT_WRITE=0)\n");

	// Test Case 1: Write to Slave 0 and read back
	doTransact(5'h0A, 32'hDEADBEEF, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0A, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("Test 1: Slave 0 address 0x%02x - Expected: 0xDEADBEEF, Got: 0x%08x", addr_in, d_out);

	// Test Case 2: Different address in Slave 0
	doTransact(5'h0B, 32'hCAFEBABE, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0B, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("Test 2: Slave 0 address 0x%02x - Expected: 0xCAFEBABE, Got: 0x%08x", addr_in, d_out);

	// Test Case 3: Write to Slave 1 (no write waitstates)
	doTransact(5'h0A, 32'hDEDEDEDE, 1'b1, ADDR_SLAVE_1);
	doTransact(5'h0A, 32'h0, 1'b0, ADDR_SLAVE_1);
	$display("Test 3: Slave 1 address 0x%02x - Expected: 0xDEDEDEDE, Got: 0x%08x", addr_in, d_out);

	// Test Case 4: Different address in Slave 1
	doTransact(5'h0B, 32'hBEEFBEEF, 1'b1, ADDR_SLAVE_1);
	doTransact(5'h0B, 32'h0, 1'b0, ADDR_SLAVE_1);
	$display("Test 4: Slave 1 address 0x%02x - Expected: 0xBEEFBEEF, Got: 0x%08x\n", addr_in, d_out);

	// ===================================================================
	// SECTION 2: Waitstate Verification Tests
	// ===================================================================
	$display("=== Waitstate Tests ===\n");

	// Test Case 5: Read from Slave 0 (2 read waitstates expected)
	$display("Test 5: Slave 0 READ with 2 waitstates");
	$display("  - Slave 0 configured with WAIT_READ=2");
	doTransact(5'h10, 32'h11111111, 1'b1, ADDR_SLAVE_0);  // First write known value
	doTransact(5'h10, 32'h0, 1'b0, ADDR_SLAVE_0);          // Read with waitstates
	$display("  - Expected: 0x11111111, Got: 0x%08x", d_out);
	$display("  - If pready stayed low for 2 cycles, data is valid\n");

	// Test Case 6: Read from Slave 1 (1 read waitstate expected)
	$display("Test 6: Slave 1 READ with 1 waitstate");
	$display("  - Slave 1 configured with WAIT_READ=1");
	doTransact(5'h10, 32'h22222222, 1'b1, ADDR_SLAVE_1);  // First write known value
	doTransact(5'h10, 32'h0, 1'b0, ADDR_SLAVE_1);          // Read with waitstate
	$display("  - Expected: 0x22222222, Got: 0x%08x", d_out);
	$display("  - If pready stayed low for 1 cycle, data is valid\n");

	// Test Case 7: Write to Slave 0 (1 write waitstate expected)
	$display("Test 7: Slave 0 WRITE with 1 waitstate");
	$display("  - Slave 0 configured with WAIT_WRITE=1");
	doTransact(5'h0C, 32'h33333333, 1'b1, ADDR_SLAVE_0);  // Write with waitstate
	doTransact(5'h0C, 32'h0, 1'b0, ADDR_SLAVE_0);          // Read back
	$display("  - Expected: 0x33333333, Got: 0x%08x", d_out);
	$display("  - If pready stayed low for 1 cycle, write was accepted\n");

	// Test Case 8: Write to Slave 1 (no write waitstate)
	$display("Test 8: Slave 1 WRITE with 0 waitstates");
	$display("  - Slave 1 configured with WAIT_WRITE=0");
	doTransact(5'h0D, 32'h44444444, 1'b1, ADDR_SLAVE_1);  // Write with NO waitstate
	doTransact(5'h0D, 32'h0, 1'b0, ADDR_SLAVE_1);          // Read back
	$display("  - Expected: 0x44444444, Got: 0x%08x", d_out);
	$display("  - pready should assert immediately on first cycle\n");

	// Test Case 9: Boundary addresses with waitstates
	$display("Test 9: Boundary address tests");
	doTransact(5'h00, 32'h12345678, 1'b1, ADDR_SLAVE_0);  // First addr of Slave 0
	doTransact(5'h00, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("  - Slave 0 addr 0x00: Expected 0x12345678, Got: 0x%08x", d_out);

	doTransact(5'h1F, 32'h87654321, 1'b1, ADDR_SLAVE_0);  // Last addr of Slave 0
	doTransact(5'h1F, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("  - Slave 0 addr 0x1F: Expected 0x87654321, Got: 0x%08x", d_out);

	doTransact(5'h00, 32'hAABBCCDD, 1'b1, ADDR_SLAVE_1);  // First addr of Slave 1
	doTransact(5'h00, 32'h0, 1'b0, ADDR_SLAVE_1);
	$display("  - Slave 1 addr 0x00: Expected 0xAABBCCDD, Got: 0x%08x", d_out);

	doTransact(5'h1F, 32'hDDBBCCAA, 1'b1, ADDR_SLAVE_1);  // Last addr of Slave 1
	doTransact(5'h1F, 32'h0, 1'b0, ADDR_SLAVE_1);
	$display("  - Slave 1 addr 0x1F: Expected 0xDDBBCCAA, Got: 0x%08x\n", d_out);

	// Test Case 10: Consecutive transactions to verify waitstate recovery
	$display("Test 10: Consecutive reads to same slave (waitstate recovery)");
	$display("  - Each read from Slave 0 should independently apply 2 waitstates");
	doTransact(5'h0E, 32'hFFFFFFFF, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0E, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("  - Read 1: Expected 0xFFFFFFFF, Got: 0x%08x", d_out);
	
	doTransact(5'h0F, 32'hEEEEEEEE, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0F, 32'h0, 1'b0, ADDR_SLAVE_0);
	$display("  - Read 2: Expected 0xEEEEEEEE, Got: 0x%08x\n", d_out);

	$finish;
end


task automatic doTransact(
	input [REG_NUM-1:0] addr,		// Address
	input [DATA_WIDTH-1:0] data,	// Data to be written (ignored for read transactions)
	input rw_sel,					// Read/Write select: 1 for write, 0 for read
	input [ADDR_MSB_len-1:0] slave_sel
	);

	// Only launch when master is idle/ready.
	while (!ready) @(posedge pclk);

	// Drive command fields before pulsing start.
	rw = rw_sel;
	d_in = (rw_sel) ? data : '0;
	addr_in = addr;
	slave_in = slave_sel;

	// Pulse start for one cycle.
	start = 1'b1;
	@(posedge pclk);
	start = 1'b0;

	// Wait for transaction accept (ready high -> low), then completion (low -> high).
	while (ready)  @(posedge pclk);
	while (!ready) @(posedge pclk);

endtask

task automatic resetDUT();

	start = 1'b0;
	rw = 1'b0;
	d_in = '0;
	addr_in = '0;
	slave_in = '0;

	prstn = 1'b0;
	@(posedge pclk) 
	prstn = 1'b1;
	@(posedge pclk); 
endtask 


initial 
	$fsdbDumpvars();

endmodule