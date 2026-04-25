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

// DUT Instantiation
APB_SYS_DUT apb_sys
(
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

	// Test Case 1: Write to Slave 0 and read back
	doTransact(5'h0A, 32'hDEADBEEF, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0A, 32'h0, 1'b0, ADDR_SLAVE_0);

	// Print results
	$display("Data read from Slave 0 at address %h: %h", addr_in, d_out);

	// Test Case 1: Write to different address in Slave 0 and read back
	doTransact(5'h0B, 32'hCAFEBABE, 1'b1, ADDR_SLAVE_0);
	doTransact(5'h0B, 32'h0, 1'b0, ADDR_SLAVE_0);

	$display("Data read from Slave 0 at address %h: %h", addr_in, d_out);

	// Test Case 3: Write to Slave 1 and read back
	doTransact(5'h0A, 32'hDEDEDEDE, 1'b1, ADDR_SLAVE_1);
	doTransact(5'h0A, 32'h0, 1'b0, ADDR_SLAVE_1);

	$display("Data read from Slave 1 at address %h: %h", addr_in, d_out);

	// Test Case 4: Write to different address in Slave 1 and read back
	doTransact(5'h0B, 32'hBEEFBEEF, 1'b1, ADDR_SLAVE_1);
	doTransact(5'h0B, 32'h0, 1'b0, ADDR_SLAVE_1);

	// Print results
	$display("Data read from Slave 1 at address %h: %h", addr_in, d_out);

	// Test case 5: Access border addresses of Slave 0 and Slave 1
	doTransact(5'h00, 32'h12345678, 1'b1, ADDR_SLAVE_0); // First address of Slave 0
	doTransact(5'h00, 32'h0, 1'b0, ADDR_SLAVE_0); // Read back first address of Slave 0

	$display("Data read from Slave 0 at address %h: %h", addr_in, d_out); // Read back first address of Slave 0

	doTransact(5'h1F, 32'h87654321, 1'b1, ADDR_SLAVE_0); // Last address of Slave 0
	doTransact(5'h1F, 32'h0, 1'b0, ADDR_SLAVE_0); // Read back last address of Slave 0

	$display("Data read from Slave 0 at address %h: %h", addr_in, d_out); // Read back last address of Slave 0

	doTransact(5'h00, 32'hAABBCCDD, 1'b1, ADDR_SLAVE_1); // First address of Slave 1
	doTransact(5'h00, 32'h0, 1'b0, ADDR_SLAVE_1); // Read back first address of Slave 1

	$display("Data read from Slave 1 at address %h: %h", addr_in, d_out); // Read back first address of Slave 1

	doTransact(5'h1F, 32'hDDBBCCAA, 1'b1, ADDR_SLAVE_1); // Last address of Slave 1
	doTransact(5'h1F, 32'h0, 1'b0, ADDR_SLAVE_1); // Read back last address of Slave 1

	$display("Data read from Slave 1 at address %h: %h", addr_in, d_out); // Read back last address of Slave 1


	$finish;
end


task automatic doTransact(
	input [REG_NUM-1:0] addr,		// Address
	input [DATA_WIDTH-1:0] data,	// Data to be written (ignored for read transactions)
	input rw_sel,					// Read/Write select: 1 for write, 0 for read
	input [ADDR_MSB_len-1:0] slave_sel
	);

	@(posedge pclk);

	// Check if master is ready for transaction
	if (!ready) begin
		$display("Master is not ready for transaction. Aborting.");
	end else begin
		// Start transaction
		start = 1'b1;
		rw = rw_sel;

		if (start) begin
			// For rw_sel=1 (write), set data
			if (rw_sel) begin
				d_in = data;
			end
			addr_in = addr;
			slave_in = slave_sel;
		end

		// Clock in the transaction
		@(posedge pclk);

		// Wait for transaction to complete
		@(posedge pclk);
		
		// Set start back to 0 after one clock cycle
		start = 1'b0;

		// Need to add buffer clocks after transaction
		@(posedge pclk);
		@(posedge pclk);
	end

endtask

task automatic resetDUT();

	start = 1'b0;
	rw = 1'b0;
	d_in = '0;
	addr_in = '0;
	slave_in = '0;

	prstn = 1'b0;
	@(posedge pclk) 
	@(posedge pclk) 
	prstn = 1'b1;
endtask 


initial 
	$fsdbDumpvars();

endmodule