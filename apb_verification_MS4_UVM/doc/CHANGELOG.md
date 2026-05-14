Changelog

**11-MAY-2026 (Martinez Corral)**
Transaction.sv - Added a field macroblock to include umv_field macros for data operations
clone, copy, compare, print, sprint (for strings), pack/unpack are the main ones introduced here

APB_DRIVER.sv
extends uvm_driver, parameterized with apb_transaction

APB_SCOREBOARD.sv
Includes functional coverage groups (FV-001, FV-004, FV-005) to track testbench efficacy
(see README file for in depth notes, too many to list here)


**13-May-2026**
**APB_MONITOR.SV**
Removed coverage groups (see APB_COVERAGE.SV), cg_apb and cg_protocol covergroups, their internal variables (cov_in_tx, cov_out_tx), and their .sample() calls. Monitor is now strictly a passive data "logger"

Added reset synchronization. Prevents the monitor from sampling garbage data during the initial system reset, fixing the transaction overcount bug
Standardized UVM messaging across all setup phases to satisfy Milestone 4c. Added `uvm_info(get_type_name(), "...", UVM_HIGH) to end of the new, build_phase, and connect_phase blocks

Failure logging: Upgraded the uvm_config_db interface fetch failure in the build_phase from a uvm_error to a uvm_fatal.

**APB_COVERAGE.sv (New Component)**
edicated UVM component extending uvm_subscriber #(apb_transaction) to passively receive broadcasted bus data without interfering with the main datapath

Relocated the cg_apb and cg_protocol covergroups from the monitor into this dedicated module

Write Implementation: write() function implemented to automatically map incoming transactions to the covergroups and trigger sampling
Phase Logging with UVM_HIGH phase completion prints (new, build_phase, connect_phase)

**APB_ENV.sv**
apb_coverage handle declared and built using UVM factory (type_id::create) within the build_phase
Added TLM Connection: agnt.mon.ap_out to cov.analysis_export during the connect_phase

Phase Logging: Cleaned up the existing $display and uvm_info statements, standardizing them with get_type_name() and proper UVM_HIGH/UVM_LOW verbosity levels
