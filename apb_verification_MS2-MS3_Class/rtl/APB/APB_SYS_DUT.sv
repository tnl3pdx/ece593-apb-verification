module APB_SYS_DUT
#(
	//Parameters
	parameter DATA_WIDTH = 32,                                           //Data bus width
	parameter ADDR_WIDTH = 32,                                           //Address bus width
	parameter REG_NUM = 5,                                               //Number of registers within a slave equals 2^REG_NUM. Address span within a given slave equals 2**REG_NUM [REG_NUM-1:0]
	parameter MASTER_COUNT = 1,                                          //Maximum allowed number of masters
	parameter SLAVE_COUNT=2                                              //Number of slaves on the bus
)
(
	// Clock/Reset
	input logic i_prstn,
	input logic i_pclk,
	
	// TB Control Signals
	input logic i_start_0,
	input logic i_rw_0,
	input logic [DATA_WIDTH-1:0] i_data_in_0,
	input logic [ADDR_WIDTH-1:0] i_addr_0,
	
	// Observing Signals for TB
	output logic [DATA_WIDTH-1:0] o_data_out_m,
	output logic o_transfer_status_m,
	output logic o_valid_m,
	output logic o_ready_m

);

// Local Parameters

localparam WORD_LEN = $clog2(DATA_WIDTH>>3);                         //Number of bits requried to specify a given byte within a word. Example: for 32-bit word 2 bits are needed for byte0-byte3. These are the LSBs of the address which are zeros in normal operation (access is word-based)
localparam ADDR_MSB_len = ADDR_WIDTH-WORD_LEN-REG_NUM;               //Part of the address bus used to select a slave unit. Address span for the salves equals 2**ADDR_MSB_len-1 

parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_0 = 0;                       //Address of slave_0
parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_1= 1;                        //Address of slave_1

// Internal Signals
logic [ADDR_WIDTH-1:0] paddr_m;                                     //Peripheral address bus on the master side of the interconnect fabric
logic pwrite_m;                                                     //Peripheral transfer direction on the master side of the interconnect fabric
logic [SLAVE_COUNT-1:0] psel_m;                                     //Peripheral slave select on the master side of the interconnect fabric
logic penable_m;                                                    //Peripheral enable on the master side of the interconnect fabric
logic [DATA_WIDTH-1:0] pwdata_m;                                    //Peripheral write data bus on the master side of the interconnect fabric

logic [DATA_WIDTH-1:0] prdata_m;                                     //Peripheral read data bus on the master side of the interconnect fabric
logic pready_m;                                                      //Ready signal. A slave may use this signal to extend an APB transfer
logic pslverr_m;                                                     //pslverr signal indicates a transfer failure

logic [ADDR_WIDTH-1:0] paddr_s;                                      //Peripheral address bus on the slave side of the interconnect fabric
logic pwrite_s;                                                      //Peripheral transfer direction on the slave side of the interconnect fabric
logic [SLAVE_COUNT-1:0] psel_s;                                      //Peripheral slave select on the slave side of the interconnect fabric
logic penable_s;                                                     //Peripheral enable on the slave side of the interconnect fabric
logic [DATA_WIDTH-1:0] pwdata_s;                                     //Peripheral write data bus on the slave side of the interconnect fabric

logic [DATA_WIDTH-1:0] prdata_s0;                                    //Peripheral read data bus on the slave side of the interconnect fabric
logic pready_s0;                                                     //Ready signal. A slave may use this signal to extend an APB transfer
logic pslverr_s0;                                                    //pslverr signal indicates a transfer failure

logic [DATA_WIDTH-1:0] prdata_s1;                                    //Peripheral read data bus on the slave side of the interconnect fabric
logic pready_s1;                                                     //Ready signal. A slave may use this signal to extend an APB transfer
logic pslverr_s1;                                                    //pslverr signal indicates a transfer failure
/*
logic request_vec;                                                   //Request indicator from the master side
logic end_of_transfer;                                               //One-cycle delayed transfer completion pulse

assign request_vec = |psel_m;

always @(posedge i_pclk or negedge i_prstn) begin
	if (!i_prstn)
		end_of_transfer <= 1'b0;
	else if (pready_m)
		end_of_transfer <= 1'b1;
	else
		end_of_transfer <= 1'b0;
end

// Interconnect Fabric (1 controller to 2 peripherals)

always @(posedge i_pclk or negedge i_prstn) begin
	if (!i_prstn) begin
		paddr_s		<=	'0;                                                                    
		pwrite_s	<=	'0;                                                         
		psel_s		<=	'0;                                                                           
		penable_s	<=	'0;                                                       
		pwdata_s	<=	'0; 

		prdata_m	<=	'0; 
		pready_m	<=	1'b0;
		pslverr_m	<=	1'b0;
	end else begin
		paddr_s		<=	paddr_m;                                                                    
		pwrite_s	<=	pwrite_m;                                                         
		psel_s		<=	psel_m; 

		if ((end_of_transfer == 1'b1) && (request_vec == 1'b1)) begin
			penable_s <= 1'b0; 
		end else begin
			penable_s <= penable_m; 
		end
	                                                      
		pwdata_s	<=	pwdata_m; 

		case (psel_m)
			2'b01: begin 
				prdata_m <= prdata_s0;                                                        
				pready_m <= pready_s0;                                                        
				pslverr_m <= pslverr_s0;
			end
			2'b10: begin 
				prdata_m <= prdata_s1;                                                        
				pready_m <= pready_s1;                                                        
				pslverr_m <= pslverr_s1;
			end
			default: begin
				prdata_m <= '0; 
				pready_m <= 1'b0;
				pslverr_m <= 1'b0;
			end
		endcase
	end
end*/

assign prdata_m = (psel_m[0]) ? prdata_s0 : 
					(psel_m[1]) ? prdata_s1 : '0;
assign pready_m = (psel_m[0]) ? pready_s0 : 
					(psel_m[1]) ? pready_s1 : 1'b0;
assign pslverr_m = (psel_m[0]) ? pslverr_s0 : 
					(psel_m[1]) ? pslverr_s1 : 1'b0;

APB_Master
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), 
.SLAVE_COUNT(SLAVE_COUNT), .ADDR_MSB_len(ADDR_MSB_len), 
.ADDR_SLAVE_0(ADDR_SLAVE_0), .ADDR_SLAVE_1(ADDR_SLAVE_1)) m0 (
	// Clock/Reset
	.i_prstn(i_prstn),                                                           
	.i_pclk(i_pclk),      

	// TB Control Signals
	.i_command(i_rw_0),
	.i_start(i_start_0),                                                           
	.i_data_in(i_data_in_0),                                                                       
	.i_addr_in(i_addr_0),

	// Inputs from Peripherals
	.i_prdata(prdata_m),                                                        
	.i_pready(pready_m),   
	.i_pslverr(pslverr_m),

	// Outputs to Peripherals
	.o_paddr(paddr_m),                                                          
	.o_pwrite(pwrite_m),                                                        
	.o_psel(psel_m),                                                            
	.o_penable(penable_m),                                                      
	.o_pwdata(pwdata_m),
	
	
	// Observing Signals for TB                                                        
	.o_data_out(o_data_out_m),
	.o_transfer_status(o_transfer_status_m),
	.o_valid(o_valid_m),
	.o_ready(o_ready_m)
	);


/*
APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(0), .WAIT_READ(0)) mem0 (
	// Clock/Reset
	.i_prstn(i_prstn),                                                           
	.i_pclk(i_pclk),                                                             
	
	// Input from APB master
	.i_paddr(paddr_s),                                                                   
	.i_pwrite(pwrite_s),                                                        
	.i_psel(psel_s[0]),                                                                            
	.i_penable(penable_s),                                                      
	.i_pwdata(pwdata_s),

	// Output to APB master
	.o_prdata(prdata_s0),                                                        
	.o_pready(pready_s0),                                                        
	.o_pslverr(pslverr_s0)
	);

APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(0), .WAIT_READ(0)) mem1 (
	// Clock/Reset
	.i_prstn(i_prstn),                                                           
	.i_pclk(i_pclk),                                                             
	
	// Input from APB master
	.i_paddr(paddr_s),                                                                   
	.i_pwrite(pwrite_s),                                                        
	.i_psel(psel_s[1]),                                                                            
	.i_penable(penable_s),                                                      
	.i_pwdata(pwdata_s),                                                         
	
	// Output to APB master
	.o_prdata(prdata_s1),                                                        
	.o_pready(pready_s1),                                                        
	.o_pslverr(pslverr_s1)
	);
*/


APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(0), .WAIT_READ(0)) mem0 (
	// Clock/Reset
	.i_prstn(i_prstn),                                                           
	.i_pclk(i_pclk),                                                             
	
	// Input from APB master
	.i_paddr(paddr_m),                                                                   
	.i_pwrite(pwrite_m),                                                        
	.i_psel(psel_m[0]),                                                                            
	.i_penable(penable_m),                                                      
	.i_pwdata(pwdata_m),

	// Output to APB master
	.o_prdata(prdata_s0),                                                        
	.o_pready(pready_s0),                                                        
	.o_pslverr(pslverr_s0)
	);

APB_Slave
#(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_NUM(REG_NUM), .WAIT_WRITE(0), .WAIT_READ(0)) mem1 (
	// Clock/Reset
	.i_prstn(i_prstn),                                                           
	.i_pclk(i_pclk),                                                             
	
	// Input from APB master
	.i_paddr(paddr_m),                                                                   
	.i_pwrite(pwrite_m),                                                        
	.i_psel(psel_m[1]),                                                                            
	.i_penable(penable_m),                                                      
	.i_pwdata(pwdata_m),                                                         
	
	// Output to APB master
	.o_prdata(prdata_s1),                                                        
	.o_pready(pready_s1),                                                        
	.o_pslverr(pslverr_s1)
	);


endmodule