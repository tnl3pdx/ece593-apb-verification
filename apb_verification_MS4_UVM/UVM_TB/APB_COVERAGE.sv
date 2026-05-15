`include "uvm_macros.svh"
import uvm_pkg::*;


// Declaring two custom analysis import suffixes as to have two separate write()
// functions in the same class
`uvm_analysis_imp_decl(_mon_in)
`uvm_analysis_imp_decl(_mon_out)

class apb_coverage extends uvm_component; // Upgraded from uvm_subscriber
    `uvm_component_utils(apb_coverage)

    // New ports for 2 bus interfaces
    uvm_analysis_imp_mon_in  #(apb_transaction, apb_coverage) cov_export_in;
    uvm_analysis_imp_mon_out #(apb_transaction, apb_coverage) cov_export_out;

    apb_transaction cov_in_tx;
    apb_transaction cov_out_tx;

    // =========================================================
    // FV-006 Functional Coverage Model (Input Interface)
    // =========================================================
    covergroup cg_apb;
        option.per_instance = 1;
        option.name = "APB_Functional_Coverage";

        cp_rw: coverpoint cov_in_tx.rw {
            bins read  = {0};
            bins write = {1};
            // THE FIX: Transition coverage bins!
            bins read_to_write = (0 => 1);
            bins write_to_read = (1 => 0);
            bins write_to_write = (1 => 1);
            bins read_to_read = (0 => 0);
        }

        cp_slave: coverpoint cov_in_tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] {
            bins slave0_mem   = {0};
            bins slave1_mem   = {1};
            bins slave2_timer = {2};
        }
        cx_slave_rw: cross cp_slave, cp_rw;
    endgroup

    // =========================================================
    // FV-003: APB Protocol Functional Coverage (Output Interface)
    // =========================================================
    covergroup cg_protocol;
        option.per_instance = 1;
        option.name = "FV-003_Protocol";

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

    // Phasing & Setup
    function new(string name = "apb_coverage", uvm_component parent);
        super.new(name, parent);
        cg_apb = new();
        cg_protocol = new();
        `uvm_info("APB_COV", "APB Coverage initialized", UVM_HIGH)
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Build the two receiving ports
        cov_export_in  = new("cov_export_in", this);
        cov_export_out = new("cov_export_out", this);
        `uvm_info(get_type_name(), "Build Phase completed", UVM_HIGH)
    endfunction

    // 2 separate write functions for the two bus interfaces    
    // Automatically called by the Input Monitor port
    function void write_mon_in(apb_transaction t);
        cov_in_tx = t;
        cg_apb.sample();
        `uvm_info("APB_COV", "Sampled INPUT transaction for coverage", UVM_DEBUG)
    endfunction

    // Automatically called by the Output Monitor port
    function void write_mon_out(apb_transaction t);
        cov_out_tx = t;
        cg_protocol.sample();
        `uvm_info("APB_COV", "Sampled OUTPUT transaction for coverage", UVM_DEBUG)
    endfunction

endclass : apb_coverage