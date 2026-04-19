module APB_Timer(i_prstn,i_pclk,i_paddr,i_pwrite,i_psel,i_penable,i_pwdata,o_prdata,o_pready,o_pslverr);



//Parameters
parameter DATA_WIDTH = 32;                                    //Data bus width
parameter ADDR_WIDTH = 32;                                    //Address bus width

parameter WAIT_WRITE = 0;                                     //Number of wait cycles following a write command
parameter WAIT_READ = 0;                                      //Number of wait cycles following a read command
localparam WAIT_MAX = 3;                                      //Maximum number of wait cycles is 2^WAIT_MAX-1. Note: can also be paramatrized to allow per-slave configuration.

parameter num_timers


//Inputs
input logic i_prstn;                                          //Active high logic 
input logic i_pclk;                                           //System's clock

input logic [ADDR_WIDTH-1:0] i_paddr;                         //Peripheral address bus
input logic i_pwrite;                                         //Peripheral transfer direction
input logic i_psel;                                           //Peripheral slave select
input logic i_penable;                                        //Peripheral enable
input logic [DATA_WIDTH-1:0] i_pwdata;                        //Peripheral write data bus

//Outputs
output logic [DATA_WIDTH-1:0] o_prdata;                       //Peripheral read data bus
output logic o_pready;                                        //Read signal. The slave issues this signal to extend an APB transfer.
output logic o_pslverr;                                       //This signal indicates transfer failure. If it is logic high upon 'pread','psel' and 'penable' negative edge (i.e at the end of a read/write operation).

// Internal Signals
logic [WAIT_MAX-1:0] count_pready;                            //Wait state counter 

// Timer Registers
logic [DATA_WIDTH-1:0] t_reg [num_timers];



endmodule