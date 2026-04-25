package PARAMS;
	// Parameters
	parameter DATA_WIDTH = 32;									//Data bus width
	parameter ADDR_WIDTH = 32;									//Address bus width
	parameter REG_NUM = 5;										//Number of registers within a slave equals 2^REG_NUM. Address span within a given slave equals 2**REG_NUM [REG_NUM-1:0]
	parameter MASTER_COUNT = 1;									//Maximum allowed number of masters
	parameter SLAVE_COUNT=2;									//Number of slaves on the bus

	localparam WORD_LEN = $clog2(DATA_WIDTH>>3);				//Number of bits requried to specify a given byte within a word. Example: for 32-bit word 2 bits are needed for byte0-byte3. These are the LSBs of the address which are zeros in normal operation (access is word-based)
	parameter ADDR_MSB_len = ADDR_WIDTH-WORD_LEN-REG_NUM;		//Part of the address bus used to select a slave unit. Address span for the salves equals 2**ADDR_MSB_len-1 

	parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_0 = 0;				//Address of slave_0 (memory 0)
	parameter [ADDR_MSB_len-1:0] ADDR_SLAVE_1= 1;				//Address of slave_1 (memory 1)

 	// Index mapping for peripheral type (0 for memory, 1 for timer)
	parameter TYPE_MEM = 0;
	parameter TYPE_TIMER = 1;

	// Create array for peripheral types based on slave selection
	parameter int PERIPH_TYPE[SLAVE_COUNT] = '{TYPE_MEM, TYPE_MEM};

	// Waitstate configurations for slaves
	parameter WAIT_WRITE_S0 = 1;								//Waitstates for Slave 0 writes
	parameter WAIT_READ_S0 = 2;									//Waitstates for Slave 0 reads
	parameter WAIT_WRITE_S1 = 0;								//Waitstates for Slave 1 writes
	parameter WAIT_READ_S1 = 1;									//Waitstates for Slave 1 reads
endpackage : PARAMS