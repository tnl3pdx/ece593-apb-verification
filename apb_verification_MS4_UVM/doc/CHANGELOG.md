Changelog

**11-MAY-2026 (Martinez Corral)**
Transaction.sv - Added a field macroblock to include umv_field macros for data operations
clone, copy, compare, print, sprint (for strings), pack/unpack are the main ones introduced here

APB_DRIVER.sv
extends uvm_driver, parameterized with apb_transaction

APB_SCOREBOARD.sv
Includes functional coverage groups (FV-001, FV-004, FV-005) to track testbench efficacy
(see README file for in depth notes, too many to list here)