module APB_SYS_DUT
#(
	//Parameters
	parameter DATA_WIDTH = 32,
	parameter ADDR_WIDTH = 32,
	parameter REG_NUM = 5,
	parameter MASTER_COUNT = 1,                                  
	parameter SLAVE_COUNT = 3,                                           // Default updated to 3
	parameter WAIT_WRITE_S0 = 0,                                  
	parameter WAIT_READ_S0 = 0,
	parameter WAIT_WRITE_S1 = 0,                                     
	parameter WAIT_READ_S1 = 0,
	parameter WAIT_WRITE_S2 = 0,
	parameter WAIT_READ_S2 = 0,
	parameter NUM_TIMERS = 2
)
(
	apb_external_if ext_if
);

// Local Parameters
localparam WORD_LEN = $clog2(DATA_WIDTH>>3);
localparam ADDR_MSB_len = ADDR_WIDTH-WORD_LEN-REG_NUM;

parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_0 = 0;
parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_1 = 1;
parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_2 = 2;                       // Slave 2 explicitly defined

// Internal interface instances
apb_bus_if #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .SLAVE_COUNT(SLAVE_COUNT)) bus_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));

apb_slave_if #(.DATA_WIDTH(DATA_WIDTH)) slave0_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));
apb_slave_if #(.DATA_WIDTH(DATA_WIDTH)) slave1_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n));
apb_slave_if #(.DATA_WIDTH(DATA_WIDTH)) slave2_if (.clk(ext_if.clk), .rst_n(ext_if.rst_n)); // Slave 2 Interface

// Interconnect response muxing on interface signals
assign bus_if.prdata = (bus_if.psel[0]) ? slave0_if.prdata :
					   (bus_if.psel[1]) ? slave1_if.prdata : 
                       (bus_if.psel[2]) ? slave2_if.prdata : '0;

assign bus_if.pready = (bus_if.psel[0]) ? slave0_if.pready :
					   (bus_if.psel[1]) ? slave1_if.pready : 
                       (bus_if.psel[2]) ? slave2_if.pready : 1'b0;

assign bus_if.pslverr= (bus_if.psel[0]) ? slave0_if.pslverr :
					   (bus_if.psel[1]) ? slave1_if.pslverr : 
                       (bus_if.psel[2]) ? slave2_if.pslverr : 1'b0;

APB_Master #(
    .DATA_WIDTH(DATA_WIDTH), 
    .ADDR_WIDTH(ADDR_WIDTH),
    .SLAVE_COUNT(SLAVE_COUNT), 
    .ADDR_MSB_len(ADDR_MSB_len),
    .ADDR_SLAVE_0(ADDR_SLAVE_0), 
    .ADDR_SLAVE_1(ADDR_SLAVE_1),
    .ADDR_SLAVE_2(ADDR_SLAVE_2)                                      // EXPLICIT MAPPING FIXED
) m0 (
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

APB_Slave #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(WAIT_WRITE_S0), .WAIT_READ(WAIT_READ_S0)
) mem0 (
	.i_prstn(ext_if.rst_n),
	.i_pclk(ext_if.clk),
	.i_paddr(bus_if.paddr),
	.i_pwrite(bus_if.pwrite),
	.i_psel(bus_if.psel[0]),
	.i_penable(bus_if.penable),
	.i_pwdata(bus_if.pwdata),
	.o_prdata(slave0_if.prdata),
	.o_pready(slave0_if.pready),
	.o_pslverr(slave0_if.pslverr)
);

APB_Slave #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(WAIT_WRITE_S1), .WAIT_READ(WAIT_READ_S1)
) mem1 (
	.i_prstn(ext_if.rst_n),
	.i_pclk(ext_if.clk),
	.i_paddr(bus_if.paddr),
	.i_pwrite(bus_if.pwrite),
	.i_psel(bus_if.psel[1]),
	.i_penable(bus_if.penable),
	.i_pwdata(bus_if.pwdata),
	.o_prdata(slave1_if.prdata),
	.o_pready(slave1_if.pready),
	.o_pslverr(slave1_if.pslverr)
);

APB_Timer #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .WAIT_WRITE(WAIT_WRITE_S2), .WAIT_READ(WAIT_READ_S2), .NUM_TIMERS(NUM_TIMERS)
) timer0 (
    .i_prstn(ext_if.rst_n),
    .i_pclk(ext_if.clk),
    .i_paddr(bus_if.paddr),
    .i_pwrite(bus_if.pwrite),
    .i_psel(bus_if.psel[2]),
    .i_penable(bus_if.penable),
    .i_pwdata(bus_if.pwdata),
    .o_prdata(slave2_if.prdata),
    .o_pready(slave2_if.pready),
    .o_pslverr(slave2_if.pslverr)
);

endmodule