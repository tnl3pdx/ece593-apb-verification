module APB_SYS_DUT
#(
	//Parameters
	parameter DATA_WIDTH = 32,                                           //Data bus width
	parameter ADDR_WIDTH = 32,                                           //Address bus width
	parameter REG_NUM = 5,                                               //Number of registers within a slave equals 2^REG_NUM. Address span within a given slave equals 2**REG_NUM [REG_NUM-1:0]
	parameter MASTER_COUNT = 1,                                          //Maximum allowed number of masters
	parameter SLAVE_COUNT=2,                                             //Number of slaves on the bus
	parameter WAIT_WRITE_S0 = 0,                                         //Waitstates for Slave 0 writes
	parameter WAIT_READ_S0 = 0,                                          //Waitstates for Slave 0 reads
	parameter WAIT_WRITE_S1 = 0,                                         //Waitstates for Slave 1 writes
	parameter WAIT_READ_S1 = 0                                           //Waitstates for Slave 1 reads
)
(
	apb_external_if ext_if
);

// Local Parameters
localparam WORD_LEN = $clog2(DATA_WIDTH>>3);                         //Number of bits requried to specify a given byte within a word. Example: for 32-bit word 2 bits are needed for byte0-byte3. These are the LSBs of the address which are zeros in normal operation (access is word-based)
localparam ADDR_MSB_len = ADDR_WIDTH-WORD_LEN-REG_NUM;               //Part of the address bus used to select a slave unit. Address span for the salves equals 2**ADDR_MSB_len-1

parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_0 = 0;                       //Address of slave_0
parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_1= 1;                        //Address of slave_1

// Internal interface instances used to connect DUT submodules
apb_bus_if #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .SLAVE_COUNT(SLAVE_COUNT)) bus_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));
apb_slave_if #(.DATA_WIDTH(DATA_WIDTH)) slave0_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));
apb_slave_if #(.DATA_WIDTH(DATA_WIDTH)) slave1_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));

// Interconnect response muxing on interface signals
assign bus_if.prdata = (bus_if.psel[0]) ? slave0_if.prdata :
					   (bus_if.psel[1]) ? slave1_if.prdata : '0;
assign bus_if.pready = (bus_if.psel[0]) ? slave0_if.pready :
					   (bus_if.psel[1]) ? slave1_if.pready : 1'b0;
assign bus_if.pslverr = (bus_if.psel[0]) ? slave0_if.pslverr :
					    (bus_if.psel[1]) ? slave1_if.pslverr : 1'b0;

APB_Master
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
.SLAVE_COUNT(SLAVE_COUNT), .ADDR_MSB_len(ADDR_MSB_len),
.ADDR_SLAVE_0(ADDR_SLAVE_0), .ADDR_SLAVE_1(ADDR_SLAVE_1)) m0 (
	// Clock/Reset
	.i_prstn(ext_if.rst_n),
	.i_pclk(ext_if.clk),

	// TB Control Signals
	.i_command(ext_if.rw),
	.i_start(ext_if.start),
	.i_data_in(ext_if.data_in),
	.i_addr_in(ext_if.addr),

	// Inputs from Peripherals
	.i_prdata(bus_if.prdata),
	.i_pready(bus_if.pready),
	.i_pslverr(bus_if.pslverr),

	// Outputs to Peripherals
	.o_paddr(bus_if.paddr),
	.o_pwrite(bus_if.pwrite),
	.o_psel(bus_if.psel),
	.o_penable(bus_if.penable),
	.o_pwdata(bus_if.pwdata),

	// Observing Signals for TB
	.o_data_out(ext_if.data_out),
	.o_transfer_status(ext_if.transfer_status),
	.o_valid(ext_if.valid),
	.o_ready(ext_if.ready)
	);

APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(WAIT_WRITE_S0), .WAIT_READ(WAIT_READ_S0)) mem0 (
	// Clock/Reset
	.i_prstn(ext_if.rst_n),
	.i_pclk(ext_if.clk),

	// Input from APB master
	.i_paddr(bus_if.paddr),
	.i_pwrite(bus_if.pwrite),
	.i_psel(bus_if.psel[0]),
	.i_penable(bus_if.penable),
	.i_pwdata(bus_if.pwdata),

	// Output to APB master
	.o_prdata(slave0_if.prdata),
	.o_pready(slave0_if.pready),
	.o_pslverr(slave0_if.pslverr)
	);

APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(WAIT_WRITE_S1), .WAIT_READ(WAIT_READ_S1)) mem1 (
	// Clock/Reset
	.i_prstn(ext_if.rst_n),
	.i_pclk(ext_if.clk),

	// Input from APB master
	.i_paddr(bus_if.paddr),
	.i_pwrite(bus_if.pwrite),
	.i_psel(bus_if.psel[1]),
	.i_penable(bus_if.penable),
	.i_pwdata(bus_if.pwdata),

	// Output to APB master
	.o_prdata(slave1_if.prdata),
	.o_pready(slave1_if.pready),
	.o_pslverr(slave1_if.pslverr)
	);

endmodule