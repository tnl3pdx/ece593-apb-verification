// ==============================================================================
// CLASS_TB Master Include File
// ==============================================================================
// This file orchestrates all CLASS_TB dependencies in the correct order.
// Include this file ONLY in your top-level (APB_TOP.sv) and individual
// components will be available in the same scope.
//
// Dependency chain:
//   1. PARAMS.sv (parameter package - no dependencies)
//   2. TRANSACTION.sv (transaction classes - depends on PARAMS)
//   3. GENERATOR.sv (generates transactions - depends on TRANSACTION)
//   4. DRIVER.sv (drives interface - depends on TRANSACTION)
//   5. MONITOR_IN.sv (samples input - depends on TRANSACTION)
//   6. MONITOR_OUT.sv (samples output - depends on TRANSACTION)
//   7. SCOREBOARD.sv (golden model checker - depends on PARAMS, TRANSACTION)
//   8. TEST.sv (testbench environment - depends on all above)
// ==============================================================================

`include "CLASS_TB/PARAMS.sv"
`include "CLASS_TB/TRANSACTION.sv"
`include "CLASS_TB/GENERATOR.sv"
`include "CLASS_TB/DRIVER.sv"
`include "CLASS_TB/MONITOR_IN.sv"
`include "CLASS_TB/MONITOR_OUT.sv"
`include "CLASS_TB/SCOREBOARD.sv"
`include "CLASS_TB/TEST.sv"
