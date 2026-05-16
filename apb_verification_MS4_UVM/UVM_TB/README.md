# UVM Testbench

Milestone 4

## LLM Acknowledgement

Sections of the UVM Testbench utilized LLMs to help debug, generate, and fix the implementation. Anthropic Claude, Google Gemini, and OpenAI GPT models were used in this section.


## APB_DRIVER.sv
extends uvm_driver, parameterized with apb_transaction
`uvm_component_utils(apb_driver): Registers the driver with the UVM factory

build_phase(uvm_phase phase): Executes at time 0. Retrieves the virtual interface from the uvm_config_db to connect the driver to the physical design

run_phase(uvm_phase phase), executes the reset_dut() sequence.
Enters a forever loop that coordinates with the sequencer via TLM ports to fetch transactions (get_next_item), drive the APB pins, and signal completion (item_done).

reset_dut(): A helper task called within the run_phase to initialize the APB bus signals and synchronize with the external system reset.

Class based testbench had to manually call driver.reset() and driver.start() sequentially. APB_DRIVER automatically executes phases in a synchronized, top-down/bottom-up order across all components in the environment. Test no longer needs to manually invoke component tasks.

Uses Transaction Level Modeling (TLM) via seq_item_port.get_next_item(req) and seq_item_port.item_done()

$display/$fatal are replaced with UVM Macros (`uvm_info and `uvm_fatal)


## APB_SCOREBOARD.sv
Class Declaration: class apb_scoreboard extends uvm_scoreboard
uvm_analysis_export: Receives data streams from  mon_in and mon_out components
uvm_tlm_analysis_fifo: Buffers incoming transactions since scoreboard prediction logic requires time to process
Internal Reference Models
    golden_mem: A multi-dimensional array tracking expected memory states
    ref_timer_val: A dynamic background model simulating the countdown logic of the hardware timers

Coverage Groups: cg_data_integrity, cg_reset, and cg_timer_validation track corner cases, read/write ratios, and timer sequences.

    build_phase / connect_phase: Instantiates the TLM structures and connects the exports to the internal FIFOs.

    run_phase: Spawns three concurrent background threads using fork/join_none:

        simulate_timers: Decrements the reference timers every clock cycle.

        get_input: Fetches stimulus from the input monitor to update the golden reference models.

        get_output: Fetches responses from the output monitor, calculates the expected transaction, and compares it.

    report_phase: Automatically executes at the end of the simulation to print the final pass/fail statistics and transaction counts.

Architectural Changes: Standard SV vs. UVM implementation

TLM Integration (Replacing Mailboxes)

    Before: mailbox mon_in2sb; and mailbox mon_out2scb;

    After: uvm_analysis_export connected to uvm_tlm_analysis_fifo.

Automated Deep Copying (.clone)

    Before: The scoreboard had to manually extract fields from the incoming transaction or risk memory corruption if the transaction was overwritten

    After: $cast(expected_tx, tx.clone());

   Scoreboard instantly generates isolated, deep-copied duplicate of the incoming packet. This allows the Scoreboard to inherit the physical address and control signals

Core Verification Logic (.compare)

    Before: Nested if/else blocks manually checking every single parameter (if (tx.valid !== 1'b1 || tx.data_out !== expected || tx.status == 1'b1)).

    After: if (!tx.compare(expected_tx))

    Scoreboard leverages the uvm_comparer policy engine. UVM automatically iterates through every registered field in the transaction and checks them bit-for-bit, drastically reducing code complexity and the risk of human error

Automated Error Formatting (.sprint)

    Before: Manually constructed $error strings concatenating half a dozen variables ($error("TX FAIL / SLAVE=%0d REG=%0d ADDR=%0h...")).

    After: `uvm_error("SCB_FAIL", $sformatf("Mismatch detected:\n%s", tx.sprint()))

    If  .compare() check fails, the Scoreboard calls .sprint(). Automatically formats the failed transaction into a clean, aligned ASCII table (with hexadecimal and binary formatting handled automatically)

Automated Phasing

    Before: TB calls scoreboard.start() and scoreboard.report()

    After: Threads are launched in run_phase, and statistics are dumped in report_phase

