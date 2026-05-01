# Class-based Testbench

Milestone 2

Coverage Groups (per the VP):

FV-001 (cg_reset): implemented in SCOREBOARD.sv. Scoreboard receives the data directly from the output monitor and can check if the very first read transactions return the 0x00000000 default state before any writes can alter the memory.

FV-002 (cg_APB_phases): new class PROTOCOL_COVERAGE created in CLASS_TB. Standard monitors only look at completed transactions. FV-002 requires cycle-by-cycle visibility into the internal bus_if to watch the psel and penable signals transition between the IDLE, SETUP, and ACCESS states.

FV-003 (cg_protocol): implemented in MONITOR_OUT.sv. Tracks error versus no-error states. Output Monitor watches APB Master's response signals (specifically transfer_status which captures pslverr)

FV-004 (cg_data_integrity): To verify data integrity, the covergroup cross references the data being written and data being read for specific patterns like 0xFFFFFFFF

test write for git push



Transaction Timestamping

Files: TRANSACTION.sv, MONITOR_IN.sv, MONITOR_OUT.sv

    Added time timestamp; to the TRANSACTION class properties.

    MONITOR_IN now records $time when sampling a transaction at vif.start.

    MONITOR_OUT now records $time when sampling a transaction at vif.ready.


Scoreboard changes:

Phase Offset Calibration: Added a 50 (5 cycles at 10ns) APB_PHASE_OFFSET parameter. This accounts 
for the exact protocol delay between the input monitor capturing the write command and the output 
monitor capturing the read response.

// Added Timing Parameters
localparam int CLK_PERIOD = 10;
localparam int APB_PHASE_OFFSET = 50; // 5 cycles of protocol overhead

// Time Tracking Arrays
time timer_write_time[PARAMS::SLAVE_COUNT][]; 

// Inside get_input() for writes:
timer_write_time[slave_idx][reg_idx] = tx.timestamp; 

// Inside get_output() for reads:
time elapsed = tx.timestamp - timer_write_time[slave_idx][reg_idx];
int cycles_decremented;

if (elapsed >= APB_PHASE_OFFSET) begin
    cycles_decremented = (elapsed - APB_PHASE_OFFSET) / CLK_PERIOD;
end else begin
    cycles_decremented = 0;
end

// Subtract decremented cycles from original written value, floor at 0
if (timer_last_val[slave_idx][reg_idx] > cycles_decremented)
    expected_timer_data = timer_last_val[slave_idx][reg_idx] - cycles_decremented;
else
    expected_timer_data = '0;


Golden Model Generation: Subtracts the decremented cycles from the stored timer_last_val (flooring at 0) to generate the cycle-accurate expected value

APB_Timer.sv:
Issue: The timer was accidentally reading the Master's Slave Select bits (bit 8) as part of its internal register index. For instance, address 0x00000100 evaluated to index 64 instead of index 0. Because the index was out of bounds (num_timers = 2), the timer ignored all writes and always returned 0 on reads.

Fix: Narrowed the address decoding slice to only look at the bits dedicated to the register offset (bits [6:2] for REG_NUM = 5):

wire [31:0] timer_idx = i_paddr[WORD_LEN + 4 : WORD_LEN];


FV-005 for timer "underflow"
covergroup cg_timer_validation;
        option.per_instance = 1;
        option.name = "FV-005_Timer_Sequences";

        // Proves the timer hit exactly 0 and didn't underflow
        cp_floor_zero: coverpoint cov_data iff (cov_slave_idx == 2 && cov_rw == 0) {
            bins hit_zero = {32'h00000000};
        }

        // Proves we attempted to access an invalid timer register
        cp_oob_addr: coverpoint cov_reg_idx iff (cov_slave_idx == 2) {
            bins valid_regs = {[0:1]};
            bins oob_regs = {[2:31]}; 
        }

        // Proves a write occurred while the timer was actively counting > 0
        cp_override: coverpoint cov_timer_override iff (cov_slave_idx == 2 && cov_rw == 1) {
            bins occurred = {1};
        }
    endgroup

