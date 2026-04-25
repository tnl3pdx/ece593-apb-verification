// ==============================================================================
// APB Verification Testbench Interfaces
// ==============================================================================
// Defines interfaces for class-based testbenching of APB_SYS_DUT
// Three interface layers:
//   1. apb_external_if   - High-level master commands/responses (top-level)
//   2. apb_bus_if        - Internal APB protocol signals (interconnect)
//   3. apb_slave_if      - Per-slave response signals (detailed observation)
// ==============================================================================

// ==============================================================================
// Interface 1: APB External Interface
// ==============================================================================
// Purpose: Captures master-level commands and responses at DUT top-level
// Used by: Transaction generators, response monitors
//
interface apb_external_if (
  input logic clk,
  input logic rst_n
);
  // Master command signals (stimulus)
  logic start;
  logic rw;           // 1=write, 0=read
  logic [31:0] data_in;
  logic [31:0] addr;
  
  // Master response signals (observation)
  logic [31:0] data_out;
  logic transfer_status;  // 0=success, 1=error
  logic valid;
  logic ready;

endinterface : apb_external_if

// ==============================================================================
// Interface 2: APB Bus Interface
// ==============================================================================
// Purpose: Captures internal APB protocol signals at interconnect fabric level
// Used by: Protocol monitors, golden model, detailed scoreboarding
//
interface apb_bus_if (
  input logic clk,
  input logic rst_n
);
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 32;
  parameter SLAVE_COUNT = 2;

  // Master to Slaves (M2S)
  logic [ADDR_WIDTH-1:0] paddr;
  logic pwrite;
  logic [SLAVE_COUNT-1:0] psel;
  logic penable;
  logic [DATA_WIDTH-1:0] pwdata;
  
  // Slaves to Master (S2M) - Multiplexed responses
  logic [DATA_WIDTH-1:0] prdata;
  logic pready;
  logic pslverr;

endinterface : apb_bus_if

// ==============================================================================
// Interface 3: APB Slave Response Interface
// ==============================================================================
// Purpose: Captures individual slave responses for detailed verification
// Used by: Memory golden model, slave-specific monitors, coverage collection
//
interface apb_slave_if (
  input logic clk,
  input logic rst_n
);
  parameter DATA_WIDTH = 32;

  // Slave response signals
  logic [DATA_WIDTH-1:0] prdata;
  logic pready;
  logic pslverr;

endinterface : apb_slave_if

// ==============================================================================
// Bind Helper: APB_SYS_DUT internal signal tap
// ==============================================================================
// This module is bound into APB_SYS_DUT and exposes internal APB wires to
// class-based TB interfaces without changing APB_SYS_DUT port definitions.
//
module apb_sys_if_bind (
  apb_bus_if mon_bus_if,
  apb_slave_if mon_slave0_if,
  apb_slave_if mon_slave1_if
);
  // Mirror APB master-side interface inside APB_SYS_DUT
  assign mon_bus_if.paddr   = bus_if.paddr;
  assign mon_bus_if.pwrite  = bus_if.pwrite;
  assign mon_bus_if.psel    = bus_if.psel;
  assign mon_bus_if.penable = bus_if.penable;
  assign mon_bus_if.pwdata  = bus_if.pwdata;
  assign mon_bus_if.prdata  = bus_if.prdata;
  assign mon_bus_if.pready  = bus_if.pready;
  assign mon_bus_if.pslverr = bus_if.pslverr;

  // Mirror per-slave response interfaces inside APB_SYS_DUT
  assign mon_slave0_if.prdata  = slave0_if.prdata;
  assign mon_slave0_if.pready  = slave0_if.pready;
  assign mon_slave0_if.pslverr = slave0_if.pslverr;

  assign mon_slave1_if.prdata  = slave1_if.prdata;
  assign mon_slave1_if.pready  = slave1_if.pready;
  assign mon_slave1_if.pslverr = slave1_if.pslverr;
endmodule : apb_sys_if_bind

// ==============================================================================
// END Interfaces and bind helpers
// ==============================================================================
