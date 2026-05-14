`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_coverage extends uvm_subscriber #(apb_transaction);
    `uvm_component_utils(apb_coverage)

    // Transaction handle used by covergroups
    apb_transaction cov_tx;

    // =========================================================
    // FV-006 Functional Coverage Model
    // =========================================================
    covergroup cg_apb;
        option.per_instance = 1;
        option.name = "APB_Functional_Coverage";

        cp_rw: coverpoint cov_tx.rw {
            bins read  = {0};
            bins write = {1};
        }

        cp_slave: coverpoint cov_tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len] {
            bins slave0_mem   = {0};
            bins slave1_mem   = {1};
            bins slave2_timer = {2};
        }
        cx_slave_rw: cross cp_slave, cp_rw;
    endgroup

    // =========================================================
    // FV-003: APB Protocol Functional Coverage
    // =========================================================
    covergroup cg_protocol;
        option.per_instance = 1;
        option.name = "FV-003_Protocol";

        cp_rw: coverpoint cov_tx.rw {
            bins read  = {0};
            bins write = {1};
        }

        cp_error: coverpoint cov_tx.transfer_status {
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
        `uvm_info(get_type_name(), "Constructor [new] completed", UVM_HIGH)
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "Build Phase completed", UVM_HIGH)
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info(get_type_name(), "Connect Phase completed", UVM_HIGH)
    endfunction

    // Subscriber Function
    // Automatically called by  Monitor via analysis port
    virtual function void write(apb_transaction t);
        // Map incoming broadcasted transaction to coverage handle
        cov_tx = t;
        
        // Sample the data
        cg_apb.sample();
        cg_protocol.sample();
        
        `uvm_info("COV", "Sampled transaction for protocol coverage", UVM_DEBUG)
    endfunction

endclass : apb_coverage