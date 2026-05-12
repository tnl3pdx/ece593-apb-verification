# UVM Testbench

Milestone 4


**APB_DRIVER.sv**
extends uvm_driver, parameterized with apb_transaction
`uvm_component_utils(apb_driver): Registers the driver with the UVM factory

build_phase(uvm_phase phase): Executes at time 0. Retrieves the virtual interface from the uvm_config_db to connect the driver to the physical design

run_phase(uvm_phase phase), executes the reset_dut() sequence.
Enters a forever loop that coordinates with the sequencer via TLM ports to fetch transactions (get_next_item), drive the APB pins, and signal completion (item_done).

reset_dut(): A helper task called within the run_phase to initialize the APB bus signals and synchronize with the external system reset.

Class based testbench had to manually call driver.reset() and driver.start() sequentially. APB_DRIVER automatically executes phases in a synchronized, top-down/bottom-up order across all components in the environment. Test no longer needs to manually invoke component tasks.

Uses Transaction Level Modeling (TLM) via seq_item_port.get_next_item(req) and seq_item_port.item_done()

$display/$fatal are replaced with UVM Macros (`uvm_info and `uvm_fatal)