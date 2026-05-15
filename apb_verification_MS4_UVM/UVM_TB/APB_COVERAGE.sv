class apb_coverage extends uvm_component;
    `uvm_component_utils(apb_coverage)

    // Transaction handle used by covergroups
    apb_transaction cov_tx;

    // Coverage state variables for migrated covergroups (FV-001, FV-004, FV-005)
    int cov_slave_idx, cov_reg_idx;
    bit cov_rw;
    bit [PARAMS::DATA_WIDTH-1:0] cov_data;
    bit cov_timer_override;

    // TLM interface for write transactions from scoreboard
    uvm_analysis_export #(apb_transaction) cov_write_export;
    uvm_tlm_analysis_fifo #(apb_transaction) cov_write_fifo;

    // =========================================================
    // FV-001 Reset Coverage
    // =========================================================
    covergroup cg_reset;
        option.per_instance = 1;
        option.name = "FV-001_Reset";
        cp_s0_regs: coverpoint cov_reg_idx iff (cov_slave_idx == 0 && cov_rw == 0 && cov_data == 32'h0) {
            bins regs[] = {[0:31]};
        }
        cp_s1_regs: coverpoint cov_reg_idx iff (cov_slave_idx == 1 && cov_rw == 0 && cov_data == 32'h0) {
            bins regs[] = {[0:31]};
        }
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

    // =========================================================
    // FV-004 Data Integrity Coverage
    // =========================================================
    covergroup cg_data_integrity;
        option.per_instance = 1;
        option.name = "FV-004_Data_Integrity";
        cp_slave: coverpoint cov_slave_idx {
            bins slave0 = {0}; bins slave1 = {1}; bins slave2 = {2};
        }
        cp_data: coverpoint cov_data {
            bins all_zeros = {32'h00000000};
            bins all_ones  = {32'hFFFFFFFF};
            bins alt_a     = {32'hAAAAAAAA};
            bins alt_5     = {32'h55555555};
            bins others    = default;
        }
        cp_rw: coverpoint cov_rw {
            bins read  = {0}; bins write = {1};
        }
        cx_integrity: cross cp_slave, cp_data, cp_rw;
    endgroup

    // =========================================================
    // FV-005 Timer Validation Coverage
    // =========================================================
    covergroup cg_timer_validation;
        option.per_instance = 1;
        option.name = "FV-005_Timer_Sequences";
        cp_floor_zero: coverpoint cov_data iff (cov_slave_idx == 2 && cov_rw == 0) {
            bins hit_zero = {32'h00000000};
        }
        cp_oob_addr: coverpoint cov_reg_idx iff (cov_slave_idx == 2) {
            bins valid_regs = {[0:1]}; bins oob_regs = {[2:31]}; 
        }
        cp_override: coverpoint cov_timer_override iff (cov_slave_idx == 2 && cov_rw == 1) {
            bins occurred = {1};
        }
    endgroup

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

    // Phasing & Setup
    function new(string name = "apb_coverage", uvm_component parent);
        super.new(name, parent);
        cg_apb = new();
        cg_protocol = new();
        cg_data_integrity = new();
        cg_reset = new();
        cg_timer_validation = new();
        `uvm_info("APV_COV", "APB Coverage initialized", UVM_MEDIUM)
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        `uvm_info("APV_COV", "Building Coverage components (analysis ports and FIFOs)", UVM_MEDIUM)
        
        cov_write_export = new("cov_write_export", this);
        cov_write_fifo = new("cov_write_fifo", this);
        
        `uvm_info("APV_COV", "Coverage ports initialized", UVM_MEDIUM)
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        `uvm_info("APV_COV", "Connecting coverage analysis exports to FIFOs", UVM_MEDIUM)
        
        cov_write_export.connect(cov_write_fifo.analysis_export);
        
        `uvm_info("APV_COV", "Coverage connections established", UVM_MEDIUM)
    endfunction

    // Run Phase
    task run_phase(uvm_phase phase);
        `uvm_info("APV_COV", "Starting Coverage component", UVM_MEDIUM)
        fork
            process_forwarded_transactions();
        join_none
    endtask

    // Process all transactions forwarded from scoreboard (both input and output)
    // Samples all covergroups in a single path based on transaction type
    task process_forwarded_transactions();
        apb_transaction tx;
        int slave_idx, reg_idx;
        
        forever begin
            cov_write_fifo.get(tx);
            
            // Decode slave and register indices using PARAMS helpers
            slave_idx = PARAMS::addr_to_slave_idx(tx.addr);
            reg_idx = PARAMS::addr_to_reg_idx(tx.addr);
            
            // Use transaction data to populate coverage handle and variables
            cov_tx = tx;
            cov_slave_idx = slave_idx;
            cov_reg_idx = reg_idx;
            cov_rw = tx.rw;
            
            // Sample baseline protocol and functional coverage (FV-003, FV-006)
            cg_apb.sample();
            cg_protocol.sample();
            
            // Illegal transactions: only sample FV-005 timer validation
            if (tx.illegal) begin
                if (slave_idx == 2) begin
                    cov_data = tx.data_in;  // Use available input data
                    cov_timer_override = 1'b0;  // N/A for illegal
                    cg_timer_validation.sample();
                end
                `uvm_info("APV_COV", $sformatf("Sampled illegal transaction: SLAVE=%0d REG=%0d", slave_idx, reg_idx), UVM_HIGH)
            end
            // Write transactions: sample FV-004 and FV-005 with write data and timer override
            else if (tx.rw) begin
                cov_data = tx.data_in;
                cov_timer_override = tx.timer_override;
                cg_data_integrity.sample();
                cg_timer_validation.sample();
                `uvm_info("APV_COV", $sformatf("Sampled write transaction: SLAVE=%0d REG=%0d DATA=0x%08x TIMER_OVERRIDE=%0b", 
                    slave_idx, reg_idx, tx.data_in, tx.timer_override), UVM_HIGH)
            end
            // Read transactions: sample FV-001, FV-004 with read data
            else begin
                cov_data = tx.data_out;
                cov_timer_override = 1'b0;  // N/A for reads
                cg_data_integrity.sample();
                cg_reset.sample();
                cg_timer_validation.sample();
                `uvm_info("APV_COV", $sformatf("Sampled read transaction: SLAVE=%0d REG=%0d DATA=0x%08x", 
                    slave_idx, reg_idx, tx.data_out), UVM_HIGH)
            end
        end
    endtask

endclass : apb_coverage