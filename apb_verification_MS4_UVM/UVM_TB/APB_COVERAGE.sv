// ============================================================================
// GROUP 2 UVM TESTBENCH
// Class: apb_coverage
// Type: UVM Component (Subscriber)
// Description: Passively monitors the APB bus via dual analysis ports
// Independently tracks functional coverage for protocol integrity, reset states,
// and timer edge-cases without interfering with the scoreboard or datapath
// ============================================================================

class apb_coverage extends uvm_component; // Upgraded from uvm_subscriber
    `uvm_component_utils(apb_coverage)

    uvm_analysis_imp_mon_in  #(apb_transaction, apb_coverage) cov_mon_in_port;
    uvm_analysis_imp_mon_out #(apb_transaction, apb_coverage) cov_mon_out_port;

    apb_transaction cov_in_tx;
    apb_transaction cov_out_tx;

    int cov_in_slave_idx;
    int cov_in_reg_idx;
    int cov_out_slave_idx;
    int cov_out_reg_idx;

    // =========================================================
    // FV-001 Reset Coverage (Input Oriented)
    // =========================================================
    covergroup cg_reset;
        option.per_instance = 1;
        option.name = "FV-001_Reset";

        /* Remove: Dont have visibility to vif (could add it if needed)
        cp_reset: coverpoint cov_in_tx.rst_n {
            bins reset_deasserted = {1};
            bins reset_asserted = {0};
        }*/

        // cp_s0_regs: coverpoint cov_in_reg_idx iff (cov_in_slave_idx == 0 && cov_in_tx.rw == 0 && cov_in_tx.data_in == 32'h0) {
        //     bins regs[] = {[0:31]};
        // }

        // cp_s1_regs: coverpoint cov_in_reg_idx iff (cov_in_slave_idx == 1 && cov_in_tx.rw == 0 && cov_in_tx.data_in == 32'h0) {
        //     bins regs[] = {[0:31]};
        // }

        cp_s0_regs: coverpoint cov_out_reg_idx iff (cov_out_slave_idx == 0 && cov_out_tx.rw == 0 && cov_out_tx.data_out == 32'h0) {
            bins regs[] = {[0:31]};
        }
        cp_s1_regs: coverpoint cov_out_reg_idx iff (cov_out_slave_idx == 1 && cov_out_tx.rw == 0 && cov_out_tx.data_out == 32'h0) {
            bins regs[] = {[0:31]};
        }    

    endgroup

    // =========================================================
    // FV-002 APB Basic Operations (Input Oriented)
    // =========================================================
    covergroup cg_apb_operations;
        option.per_instance = 1;
        option.name = "FV-002_Basic_Operations";

        cp_rw: coverpoint cov_in_tx.rw {
            bins read  = {0};
            bins write = {1};
        }

        cp_rw_trans: coverpoint cov_in_tx.rw {
            bins read_to_write = (0 => 1);
            bins write_to_read = (1 => 0);
            bins write_to_write = (1 => 1);
            bins read_to_read = (0 => 0);
        }

        cp_slave: coverpoint cov_in_slave_idx {
            bins slave0_mem   = {0};
            bins slave1_mem   = {1};
            bins slave2_timer = {2};
        }
        cx_slave_rw: cross cp_slave, cp_rw;
    endgroup

    // =========================================================
    // FV-003: APB Protocol Error Response (Output Oriented)
    // =========================================================
    covergroup cg_error_resp;
        option.per_instance = 1;
        option.name = "FV-003_Protocol_Error_Response";

        cp_rw: coverpoint cov_out_tx.rw {
            bins read  = {0};
            bins write = {1};
        }

        cp_error: coverpoint cov_out_tx.transfer_status {
            bins no_error = {0};
            bins error    = {1};
        }

        cx_type_error: cross cp_rw, cp_error {
            ignore_bins read_errors = binsof(cp_rw.read) && binsof(cp_error.error);
        }
    endgroup

    // =========================================================
    // FV-004 Data Integrity Coverage (Output Oriented)
    // =========================================================
    covergroup cg_data_integrity;
        option.per_instance = 1;
        option.name = "FV-004_Data_Integrity";

        cp_slave: coverpoint cov_out_slave_idx {
            bins slave0 = {0}; bins slave1 = {1}; bins slave2 = {2};
        }

        cp_data: coverpoint cov_out_tx.data_out {
            bins all_zeros = {32'h00000000};
            bins all_ones  = {32'hFFFFFFFF};
            bins alt_a     = {32'hAAAAAAAA};
            bins alt_5     = {32'h55555555};
            bins others    = default;
        }
        
        cp_rw: coverpoint cov_out_tx.rw {
            bins read  = {0}; 
            bins write = {1};
        }

        cx_integrity: cross cp_slave, cp_data, cp_rw;

    endgroup

    // =========================================================
    // FV-005 Timer Validation Coverage (Output Oriented, focused on Slave 2)
    // =========================================================

    bit cov_timer_override;
    time timer_start_time[2];
    int  timer_duration[2];
    
    covergroup cg_timer_validation;
        option.per_instance = 1;
        option.name = "FV-005_Timer_Sequences";

        cp_floor_zero: coverpoint cov_out_tx.data_out iff (cov_out_slave_idx == 2 && cov_out_tx.rw == 0) {
            bins hit_zero = {32'h00000000};
        }

        cp_oob_addr: coverpoint cov_out_reg_idx iff (cov_out_slave_idx == 2) {
            bins valid_regs = {[0:1]}; 
            ignore_bins oob_regs = {[2:31]}; 
        }

        cp_override: coverpoint cov_timer_override iff (cov_out_slave_idx == 2 && cov_out_tx.rw == 1) {
            bins occurred = {1};
}
    endgroup


    // Phasing & Setup
    function new(string name = "apb_coverage", uvm_component parent);
        super.new(name, parent);

        cg_reset = new();
        cg_apb_operations = new();
        cg_error_resp = new();
        cg_data_integrity = new();
        cg_timer_validation = new();

        `uvm_info("APB_COV", "APB Coverage Groups initialized", UVM_MEDIUM)
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        `uvm_info("APB_COV", "Building Coverage components (analysis ports)", UVM_MEDIUM)

        // Build the two receiving ports
        // Dual port analysis implementations; allows this single component to subscribe 
        // to both the request (inpjut) and response (output) phases of bus
        cov_mon_in_port  = new("cov_mon_in_port", this);
        cov_mon_out_port = new("cov_mon_out_port", this);

        `uvm_info("APB_COV", "Coverage ports initialized", UVM_MEDIUM)
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask

    // Write functions for both analysis ports

    // Automatically triggered by input monitor
    // Evaluates sequence transitions and requested operations (rw, address ranges)
    function void write_mon_in(apb_transaction t);
        cov_in_tx = t;

        cov_in_slave_idx = PARAMS::addr_to_slave_idx(cov_in_tx.addr);
        cov_in_reg_idx = PARAMS::addr_to_reg_idx(cov_in_tx.addr);

        if (cov_in_slave_idx == 2 && cov_in_tx.rw == 1 && cov_in_reg_idx < 2) begin
        time elapsed = $time - timer_start_time[cov_in_reg_idx];
        time expected = timer_duration[cov_in_reg_idx] * PARAMS::CLK_PERIOD;

        // Override if write occurrs before timer is done
        cov_timer_override = (elapsed < expected) ? 1 : 0;

        // Update trackers with new write
        timer_start_time[cov_in_reg_idx] = $time;
        timer_duration[cov_in_reg_idx] = cov_in_tx.data_in;
        end else begin
        cov_timer_override = 0;
        end



       // cg_reset.sample();
        cg_apb_operations.sample();

        `uvm_info("APB_COV", "Sampled INPUT transaction", UVM_DEBUG)
    endfunction

    // Automatically triggered by output monitor
    // Evaluates data integrity, protocol error flags, and reset values after a transfer completes
    function void write_mon_out(apb_transaction t);
        cov_out_tx = t;

        cov_out_slave_idx = PARAMS::addr_to_slave_idx(cov_out_tx.addr);
        cov_out_reg_idx = PARAMS::addr_to_reg_idx(cov_out_tx.addr);

        cg_error_resp.sample();
        cg_data_integrity.sample();
        cg_timer_validation.sample();

        // adding reset function here, from write_mon_in() function
        cg_reset.sample();

        `uvm_info("APB_COV", "Sampled OUTPUT transaction", UVM_DEBUG)

    endfunction

endclass : apb_coverage