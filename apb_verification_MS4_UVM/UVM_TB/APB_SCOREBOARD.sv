class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    // TLM Interfaces
    uvm_analysis_export #(apb_transaction) mon_in_export;
    uvm_analysis_export #(apb_transaction) mon_out_export;

    uvm_tlm_analysis_fifo #(apb_transaction) mon_in_fifo;
    uvm_tlm_analysis_fifo #(apb_transaction) mon_out_fifo;

    // Scoreboard State Variables
    int total_tests;
    int mem_slave_count;
    int read_pass_count, read_fail_count;
    int write_pass_count, write_fail_count;
    int illegal_pass_count, illegal_fail_count;
    int total_input_count, total_output_count;
    int error_count;
    int illegal_count;

    // Per-slave and per-access-type statistics
    int slave_accesses[PARAMS::SLAVE_COUNT];
    int slave_rw_accesses[PARAMS::SLAVE_COUNT][2];
    int slave_rw_errors[PARAMS::SLAVE_COUNT][2];

    // Golden Model State
    localparam int REG_DEPTH = (1 << PARAMS::REG_NUM);
    bit [PARAMS::DATA_WIDTH-1:0] golden_mem[][];
    
    // Timer Model State
    bit [PARAMS::DATA_WIDTH:0] ref_timer_val[PARAMS::SLAVE_COUNT][];
    time ref_timer_start_time[PARAMS::SLAVE_COUNT][];
    bit ref_timer_active[PARAMS::SLAVE_COUNT][];

    bit [PARAMS::DATA_WIDTH:0] pending_start_val[PARAMS::SLAVE_COUNT][];
    time pending_start_request_time[PARAMS::SLAVE_COUNT][];
    bit pending_start_valid[PARAMS::SLAVE_COUNT][];
    
    // Slave to Model Index Mapping
    int slave_to_model_idx[PARAMS::SLAVE_COUNT];

    // Coverage Groups
    int cov_slave_idx, cov_reg_idx;
    bit cov_rw;
    bit [PARAMS::DATA_WIDTH-1:0] cov_data;
    bit cov_timer_override; 

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

    // Constructor & Build Phase
    function new(string name = "apb_scoreboard", uvm_component parent);
        super.new(name, parent);
        cg_data_integrity = new();
        cg_reset = new();
        cg_timer_validation = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_in_export  = new("mon_in_export", this);
        mon_out_export = new("mon_out_export", this);
        mon_in_fifo    = new("mon_in_fifo", this);
        mon_out_fifo   = new("mon_out_fifo", this);

        foreach (slave_to_model_idx[i]) slave_to_model_idx[i] = -1;
        mem_slave_count = 0;
        foreach (PARAMS::PERIPH_TYPE[i]) begin
            if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_MEM) begin
                slave_to_model_idx[i] = mem_slave_count;
                mem_slave_count++;
            end
            if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_TIMER) begin
                ref_timer_val[i] = new[REG_DEPTH];
                ref_timer_start_time[i] = new[REG_DEPTH];
                ref_timer_active[i] = new[REG_DEPTH];
                pending_start_val[i] = new[REG_DEPTH];
                pending_start_request_time[i] = new[REG_DEPTH];
                pending_start_valid[i] = new[REG_DEPTH];
                foreach(ref_timer_val[i][j]) begin
                    ref_timer_val[i][j] = '0; ref_timer_start_time[i][j] = 0; ref_timer_active[i][j] = 0;
                    pending_start_val[i][j] = '0; pending_start_request_time[i][j] = 0; pending_start_valid[i][j] = 0;
                end
            end
        end

        golden_mem = new[mem_slave_count];
        foreach (golden_mem[i]) begin
            golden_mem[i] = new[REG_DEPTH];
            foreach (golden_mem[i][j]) golden_mem[i][j] = '0;
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon_in_export.connect(mon_in_fifo.analysis_export);
        mon_out_export.connect(mon_out_fifo.analysis_export);
    endfunction

    task simulate_timers();
        forever begin
            #PARAMS::CLK_PERIOD;
            for (int s = 0; s < PARAMS::SLAVE_COUNT; s++) begin
                if (PARAMS::PERIPH_TYPE[s] == PARAMS::TYPE_TIMER) begin
                    foreach (ref_timer_val[s][r]) begin
                        if (ref_timer_active[s][r] && ref_timer_val[s][r] > 0) begin
                            ref_timer_val[s][r] = ref_timer_val[s][r] - 1;
                        end
                    end
                end
            end
        end
    endtask

    function bit [PARAMS::DATA_WIDTH-1:0] sample_ref_timer(int slave_idx, int reg_idx);
        sample_ref_timer = ref_timer_val[slave_idx][reg_idx];
    endfunction

    // Run Phase Threads
    virtual task run_phase(uvm_phase phase);
        `uvm_info("APB_SCB", "STARTED", UVM_HIGH)
        fork
            get_input();
            get_output();
            simulate_timers();
        join_none
    endtask
        
    task get_input();
        apb_transaction tx;
        int slave_idx, reg_idx, model_idx;
        forever begin
            mon_in_fifo.get(tx);
            total_input_count++;
            slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
            reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
            model_idx = (slave_idx < PARAMS::SLAVE_COUNT) ? slave_to_model_idx[slave_idx] : -1;
            
            if (tx.illegal) begin
                illegal_count++;
                if ((slave_idx < PARAMS::SLAVE_COUNT) && (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER)) begin
                    cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_in;
                    cg_timer_validation.sample();
                end
                `uvm_info("APB_SCB_IN", $sformatf("TX#%0d Illegal Transaction Acknowledged: ADDR=0x%08x SLAVE=%0d REG=%0d", total_input_count, tx.addr, slave_idx, reg_idx), UVM_HIGH)
            end
            else if (tx.rw) begin 
                cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_in;
                cg_data_integrity.sample();
                if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                    golden_mem[model_idx][reg_idx] = tx.data_in;
                    `uvm_info("APB_SCB_IN", $sformatf("TX#%0d Memory Write Registered: SLAVE=%0d REG=%0d ADDR=0x%08x DATA=0x%08x", total_input_count, slave_idx, reg_idx, tx.addr, tx.data_in), UVM_HIGH)
                end 
                else if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                    cov_timer_override = (ref_timer_active[slave_idx][reg_idx] && ref_timer_val[slave_idx][reg_idx] > 0) ? 1 : 0;
                    cg_timer_validation.sample();
                    pending_start_val[slave_idx][reg_idx] = tx.data_in;
                    pending_start_request_time[slave_idx][reg_idx] = tx.timestamp;
                    pending_start_valid[slave_idx][reg_idx] = 1;
                    `uvm_info("APB_SCB_IN", $sformatf("TX#%0d Timer Write Registered: SLAVE=%0d REG=%0d ADDR=0x%08x DATA=0x%08x", total_input_count, slave_idx, reg_idx, tx.addr, tx.data_in), UVM_HIGH)
                end
            end
        end
    endtask

    task get_output();
        apb_transaction tx;
        int slave_idx, reg_idx, model_idx;
        bit [PARAMS::DATA_WIDTH-1:0] expected_data;
        bit transfer_status_ok, valid_ok, data_ok, check_pass;
        forever begin
            mon_out_fifo.get(tx);
            total_output_count++;
            slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
            reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
            model_idx = (slave_idx < PARAMS::SLAVE_COUNT) ? slave_to_model_idx[slave_idx] : -1;

            if (tx.illegal) begin
                // --- ILLEGAL TRANSACTION CHECK ---
                // Only check: transfer_status should be asserted (1)
                if ((slave_idx < PARAMS::SLAVE_COUNT) && (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER)) begin
                    cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_out;
                    cg_timer_validation.sample();
                end
                
                if (tx.transfer_status != 1'b1) begin
                    illegal_fail_count++;
                    `uvm_error("APB_SCB_OUT", $sformatf("ILLEGAL FAIL: transfer_status=%0b (expected 1)", tx.transfer_status))
                end else begin
                    illegal_pass_count++;
                    `uvm_info("APB_SCB_OUT", $sformatf("ILLEGAL PASS: transfer_status=%0b", tx.transfer_status), UVM_HIGH)
                end
                continue;
            end

            if (tx.rw) begin 
                // --- WRITE COMPLETION CHECK ---
                // Check: transfer_status deasserted (0) AND valid deasserted (0)
                transfer_status_ok = (tx.transfer_status == 1'b0);
                valid_ok = (tx.valid == 1'b0);
                check_pass = transfer_status_ok && valid_ok;

                if (!check_pass) begin
                    write_fail_count++; error_count++; slave_rw_errors[slave_idx][tx.rw]++;
                    `uvm_error("APB_SCB_OUT", $sformatf("TX#%0d WRITE FAIL: transfer_status=%0b (expected 0), valid=%0b (expected 0)", total_output_count, tx.transfer_status, tx.valid))
                end else begin
                    write_pass_count++;
                    `uvm_info("APB_SCB_OUT", $sformatf("TX#%0d WRITE PASS: transfer_status=%0b, valid=%0b", total_output_count, tx.transfer_status, tx.valid), UVM_HIGH)
                    if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER && pending_start_valid[slave_idx][reg_idx]) begin
                        ref_timer_val[slave_idx][reg_idx] = (pending_start_val[slave_idx][reg_idx] > 0) ? (pending_start_val[slave_idx][reg_idx] + 2) : pending_start_val[slave_idx][reg_idx];
                        ref_timer_start_time[slave_idx][reg_idx] = tx.timestamp;
                        ref_timer_active[slave_idx][reg_idx] = (ref_timer_val[slave_idx][reg_idx] != '0);
                        pending_start_valid[slave_idx][reg_idx] = 0;
                    end
                end

            end else begin 
                // --- READ COMPLETION CHECK ---
                // Check: transfer_status deasserted (0), valid asserted (1), and data_out matches expected
                cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_out;
                cg_data_integrity.sample(); cg_reset.sample(); cg_timer_validation.sample();
                
                transfer_status_ok = (tx.transfer_status == 1'b0);
                valid_ok = (tx.valid == 1'b1);
                
                // Determine expected data based on peripheral type
                if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                    expected_data = golden_mem[model_idx][reg_idx];
                end
                else if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                    expected_data = sample_ref_timer(slave_idx, reg_idx);
                end
                else begin
                    expected_data = 32'h0; // Default for unrecognized peripherals
                end
                
                data_ok = (tx.data_out == expected_data);
                check_pass = transfer_status_ok && valid_ok && data_ok;
                
                if (!check_pass) begin
                    read_fail_count++; error_count++; slave_rw_errors[slave_idx][tx.rw]++;
                    `uvm_error("APB_SCB_OUT", $sformatf("TX#%0d READ FAIL: transfer_status=%0b (expected 0), valid=%0b (expected 1), data_out=0x%08x (expected 0x%08x)", total_output_count, tx.transfer_status, tx.valid, tx.data_out, expected_data))
                end else begin
                    read_pass_count++;
                    `uvm_info("APB_SCB_OUT", $sformatf("TX#%0d READ PASS: transfer_status=%0b, valid=%0b, data_out=0x%08x", total_output_count, tx.transfer_status, tx.valid, tx.data_out), UVM_HIGH)
                end
            end
            slave_accesses[slave_idx]++; slave_rw_accesses[slave_idx][tx.rw]++;
        end
    endtask

    // Report Phase
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("APB_SCB", "===== FINAL SCOREBOARD REPORT =====", UVM_LOW)
        `uvm_info("APB_SCB", $sformatf("WRITES: PASS=%0d FAIL=%0d", write_pass_count, write_fail_count), UVM_LOW)
        `uvm_info("APB_SCB", $sformatf("READS:  PASS=%0d FAIL=%0d", read_pass_count, read_fail_count), UVM_LOW)
        `uvm_info("APB_SCB", $sformatf("ILLEGAL TX: PASS=%0d FAIL=%0d", illegal_pass_count, illegal_fail_count), UVM_LOW)
        for (int i = 0; i < PARAMS::SLAVE_COUNT; i++) begin
            `uvm_info("APB_SCB", $sformatf("  Slave %0d: %0d accesses (WRITES=%0d (ERRORS=%0d) READS=%0d (ERRORS=%0d))", 
                i, slave_accesses[i], slave_rw_accesses[i][1], slave_rw_errors[i][1], slave_rw_accesses[i][0], slave_rw_errors[i][0]), UVM_LOW)
        end
        if (error_count == 0) begin
            `uvm_info("APB_SCB", $sformatf("VERIFICATION PASSED! TOTAL ERRORS: %0d | TRANSACTIONS VERIFIED: %0d", error_count, total_output_count), UVM_LOW)
        end else begin
            `uvm_error("APB_SCB", $sformatf("VERIFICATION FAILED! TOTAL ERRORS: %0d | TRANSACTIONS VERIFIED: %0d", error_count, total_output_count))
        end
    endfunction

endclass : apb_scoreboard