class SCOREBOARD;
    mailbox mon_in2sb;
    mailbox mon_out2scb;

    int total_tests;
    int mem_slave_count;
    int read_pass_count, read_fail_count;
    int write_pass_count, write_fail_count;
    int illegal_pass_count, illegal_fail_count;
    int total_input_count, total_output_count;
    int error_count;
    int illegal_count;

    int slave_accesses[PARAMS::SLAVE_COUNT];
    int slave_rw_accesses[PARAMS::SLAVE_COUNT][2];
    int slave_rw_errors[PARAMS::SLAVE_COUNT][2];

    localparam int REG_DEPTH = (1 << PARAMS::REG_NUM);
    bit [PARAMS::DATA_WIDTH-1:0] golden_mem[][];
    
    // Reference model state for timers (driven by a background task)
    bit [PARAMS::DATA_WIDTH:0] ref_timer_val[PARAMS::SLAVE_COUNT][];
    time ref_timer_start_time[PARAMS::SLAVE_COUNT][];
    bit ref_timer_active[PARAMS::SLAVE_COUNT][];

    // Pending start info for writes: we wait for transfer completion (ready)
    bit [PARAMS::DATA_WIDTH:0] pending_start_val[PARAMS::SLAVE_COUNT][];
    time pending_start_request_time[PARAMS::SLAVE_COUNT][];
    bit pending_start_valid[PARAMS::SLAVE_COUNT][];
    
    int slave_to_model_idx[PARAMS::SLAVE_COUNT];

    // =========================================================
    // Coverage Variables & Groups
    // =========================================================
    int cov_slave_idx, cov_reg_idx;
    bit cov_rw;
    bit [PARAMS::DATA_WIDTH-1:0] cov_data;
    bit cov_timer_override; //for FV-005

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
        // Proves we observed the 0x0 default reset state for all 32 memory registers
        cp_s0_regs: coverpoint cov_reg_idx iff (cov_slave_idx == 0 && cov_rw == 0 && cov_data == 32'h0) {
            bins regs[] = {[0:31]};
        }
        cp_s1_regs: coverpoint cov_reg_idx iff (cov_slave_idx == 1 && cov_rw == 0 && cov_data == 32'h0) {
            bins regs[] = {[0:31]};
        }
    endgroup

    // =========================================================
    // FV-005 Timer Sequences Coverage Group
    // =========================================================
    
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

    function new(mailbox mon_in2sb, mailbox mon_out2scb, int total_tests);
        int model_idx;
        this.mon_in2sb = mon_in2sb;
        this.mon_out2scb = mon_out2scb;
        this.total_tests = total_tests;
        this.read_pass_count = 0; this.read_fail_count = 0;
        this.write_pass_count = 0; this.write_fail_count = 0;
        this.illegal_pass_count = 0; this.illegal_fail_count = 0;
        this.total_input_count = 0; this.total_output_count = 0;
        this.error_count = 0;
        this.illegal_count = 0;

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
                    ref_timer_val[i][j] = '0;
                    ref_timer_start_time[i][j] = 0;
                    ref_timer_active[i][j] = 0;
                    pending_start_val[i][j] = '0;
                    pending_start_request_time[i][j] = 0;
                    pending_start_valid[i][j] = 0;
                end
            end
        end

        golden_mem = new[mem_slave_count];
        foreach (golden_mem[i]) begin
            golden_mem[i] = new[REG_DEPTH];
            foreach (golden_mem[i][j]) golden_mem[i][j] = '0;
        end

        // Initialize Covergroups
        cg_data_integrity = new();
        cg_reset = new();
        cg_timer_validation = new();
    endfunction

    task start();
        $display("[SCOREBOARD] STARTED");
        fork
            get_input();
            get_output();
            simulate_timers();
        join_none
    endtask

    // Background task: drive the reference timer model on clock ticks
    task simulate_timers();
        forever begin
            #PARAMS::CLK_PERIOD; // advance by one clock period
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

    // Return the current reference-model value for a timer register
    function bit [PARAMS::DATA_WIDTH-1:0] sample_ref_timer(int slave_idx, int reg_idx);
        sample_ref_timer = ref_timer_val[slave_idx][reg_idx];
    endfunction
        
	task get_input();
        // INPUT MONITOR PROCESSING
        TRANSACTION tx;
        int slave_idx, reg_idx, model_idx;           
        
        forever begin
            mon_in2sb.get(tx);
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
                if (tx.rw) begin
                    $display("[SCOREBOARD]\tTX#%0d (INPUT) ILLEGAL WRITE / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_IN=0x%08x",
                        total_input_count, slave_idx, reg_idx, tx.addr, tx.data_in);
                end else begin
                    $display("[SCOREBOARD]\tTX#%0d (INPUT) ILLEGAL READ / SLAVE=%0d REG=%0d ADDR=0x%08x", total_input_count, slave_idx, reg_idx, tx.addr);
                end
            end
            else if (tx.rw) begin // Write transaction
                // Sample FV-004 Coverage for Writes
                cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_in;
                cg_data_integrity.sample();

                if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                    golden_mem[model_idx][reg_idx] = tx.data_in;
                    $display("[SCOREBOARD]\tTX#%0d (INPUT) WRITE / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_IN=0x%08x",
                        total_input_count, slave_idx, reg_idx, tx.addr, tx.data_in);
                end 
                else if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                    // FV-005: Detect if timer is actively counting (will be overwritten)
                    if (ref_timer_active[slave_idx][reg_idx] && ref_timer_val[slave_idx][reg_idx] > 0)
                        cov_timer_override = 1;
                    else
                        cov_timer_override = 0;

                    // Sample the write conditions BEFORE starting the pending write
                    cg_timer_validation.sample();

                    // Record pending start for reference model; actual start waits for transfer completion (ready)
                    pending_start_val[slave_idx][reg_idx] = tx.data_in;
                    pending_start_request_time[slave_idx][reg_idx] = tx.timestamp;
                    pending_start_valid[slave_idx][reg_idx] = 1;
                    $display("[SCOREBOARD]\tTX#%0d (INPUT) WRITE (TIMER) REQUEST / timer[%0d][%0d] <= 0x%08x at %0t", 
                        total_input_count, slave_idx, reg_idx, tx.data_in, tx.timestamp); 
                end
            end
        end
    endtask

    task get_output();
        // OUTPUT MONITOR PROCESSING
        TRANSACTION tx;
        int slave_idx, reg_idx, model_idx;
        bit [PARAMS::DATA_WIDTH-1:0] expected_data;            
        
        forever begin
            mon_out2scb.get(tx);
            total_output_count++;
            slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
            reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
            model_idx = (slave_idx < PARAMS::SLAVE_COUNT) ? slave_to_model_idx[slave_idx] : -1;

            if (tx.illegal) begin
                if ((slave_idx < PARAMS::SLAVE_COUNT) && (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER)) begin
                    cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_out;
                    cg_timer_validation.sample();
                end
                if (tx.transfer_status == 1'b1) begin
                    illegal_pass_count++; 
                    $display("[SCOREBOARD]\tTX#%0d (OUTPUT) ILLEGAL TX PASS / SLAVE=%0d REG=%0d ADDR=0x%08x TRANSFER_STATUS=%0b",
                        total_output_count, slave_idx, reg_idx, tx.addr, tx.transfer_status);
                end else begin
                    illegal_fail_count++;
                    $error("[SCOREBOARD]\tTX#%0d (OUTPUT) ILLEGAL TX FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x TRANSFER_STATUS=%0b",
                        total_output_count, slave_idx, reg_idx, tx.addr, tx.transfer_status);
                end
                continue;
            end

            if (tx.rw) begin // Write Completion Check
                bit write_has_transfer_err;
                bit write_has_unexpected_valid;
                write_has_transfer_err = (tx.transfer_status == 1'b1);
                write_has_unexpected_valid = (tx.valid == 1'b1);

                if (write_has_transfer_err || write_has_unexpected_valid) begin
                    write_fail_count++; error_count++;
                    slave_rw_errors[slave_idx][tx.rw]++;
                    if (write_has_transfer_err && write_has_unexpected_valid) begin
                        $error("[SCOREBOARD]\tTX#%0d (OUTPUT) WRITE FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (combined: transfer error + unexpected valid=1)",
                            total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                    end
                    else if (write_has_unexpected_valid) begin
                        $error("[SCOREBOARD]\tTX#%0d (OUTPUT) WRITE FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (unexpected valid=1)",
                            total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                    end
                    else begin
                        $error("[SCOREBOARD]\tTX#%0d (OUTPUT) WRITE FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (transfer error)",
                            total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                    end
                end else begin
                    write_pass_count++;
                    $display("[SCOREBOARD]\tTX#%0d (OUTPUT) WRITE PASS / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x",
                        total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                    // If this was a timer write and the transfer completed successfully, start the reference model
                    if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                        if (pending_start_valid[slave_idx][reg_idx]) begin
                            // Offset ref_timer_val by 2 to account for APB transfer latency (PENABLE + READY cycle)
                            // Ref will start decrementing, but will sync to the correct value after 2 cycles
                            if (pending_start_val[slave_idx][reg_idx] > 0) begin
                                ref_timer_val[slave_idx][reg_idx] = pending_start_val[slave_idx][reg_idx] + 2;
                            end else begin
                                ref_timer_val[slave_idx][reg_idx] = pending_start_val[slave_idx][reg_idx];
                            end
                            ref_timer_start_time[slave_idx][reg_idx] = tx.timestamp; // start at completion (ready)
                            ref_timer_active[slave_idx][reg_idx] = (ref_timer_val[slave_idx][reg_idx] != '0);
                            pending_start_valid[slave_idx][reg_idx] = 0;
                            $display("[SCOREBOARD]\tREF TIMER STARTED: timer[%0d][%0d] <= 0x%08x at %0t",
                                slave_idx, reg_idx, ref_timer_val[slave_idx][reg_idx], tx.timestamp);
                        end
                    end
                end
            end else begin // Read Completion Check
                // Sample FV-001 and FV-004 Coverage for Reads
                cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_out;
                cg_data_integrity.sample();
                cg_reset.sample();
                cg_timer_validation.sample();

                if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                    expected_data = golden_mem[model_idx][reg_idx];
                    if ((tx.valid !== 1'b1) || (tx.data_out !== expected_data) || (tx.transfer_status == 1'b1)) begin
                        bit mem_has_invalid;
                        bit mem_has_data_mismatch;
                        bit mem_has_transfer_err;

                        mem_has_invalid = (tx.valid !== 1'b1);
                        mem_has_data_mismatch = (tx.data_out !== expected_data);
                        mem_has_transfer_err = (tx.transfer_status == 1'b1);

                        read_fail_count++; error_count++;
                        slave_rw_errors[slave_idx][tx.rw]++;
                        if (mem_has_invalid && mem_has_data_mismatch && mem_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid VALID=%0b + data mismatch expected=0x%08x actual=0x%08x + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid, expected_data, tx.data_out);
                        end else if (mem_has_invalid && mem_has_data_mismatch) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid VALID=%0b + data mismatch expected=0x%08x actual=0x%08x)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid, expected_data, tx.data_out);
                        end else if (mem_has_invalid && mem_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid VALID=%0b + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid);
                        end else if (mem_has_data_mismatch && mem_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: data mismatch expected=0x%08x actual=0x%08x + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, expected_data, tx.data_out);
                        end else if (mem_has_data_mismatch) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x expected=0x%08x actual=0x%08x valid=%0b",
                                total_output_count, slave_idx, reg_idx, tx.addr, expected_data, tx.data_out, tx.valid);
                        end else if (mem_has_invalid) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (VALID not asserted, valid=%0b)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid);
                        end else if (mem_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                        end else begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr);
                        end
                    end else begin
                        $display("[SCOREBOARD]\tTX#%0d (OUTPUT) READ PASS / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x",
                            total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                        read_pass_count++;
                    end
                end
                else if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                    bit timer_has_unexpected_value;

                    // Use the reference-model sampler for expected timer value
                    bit [PARAMS::DATA_WIDTH-1:0] expected_timer_data;
                    time elapsed = tx.timestamp - ref_timer_start_time[slave_idx][reg_idx];

                    // If reference model never started, expected is 0
                    expected_timer_data = sample_ref_timer(slave_idx, reg_idx);

                    timer_has_unexpected_value = (tx.data_out !== expected_timer_data);

                    if ((tx.valid !== 1'b1) || (tx.transfer_status == 1'b1) || (timer_has_unexpected_value == 1'b1)) begin
                        bit timer_has_invalid;
                        bit timer_has_transfer_err;

                        timer_has_invalid = (tx.valid !== 1'b1);
                        timer_has_transfer_err = (tx.transfer_status == 1'b1);

                        read_fail_count++; error_count++;
                        slave_rw_errors[slave_idx][tx.rw]++;
                        if (timer_has_invalid && timer_has_unexpected_value && timer_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid transfer valid=%0b + unexpected value expected=0x%08x actual=0x%08x + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid, expected_timer_data, tx.data_out);
                        end else if (timer_has_invalid && timer_has_unexpected_value) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid transfer valid=%0b + unexpected value expected=0x%08x actual=0x%08x)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid, expected_timer_data, tx.data_out);
                        end else if (timer_has_invalid && timer_has_transfer_err) begin 
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: invalid transfer valid=%0b + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid);
                        end else if (timer_has_unexpected_value && timer_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (combined: unexpected value expected=0x%08x actual=0x%08x + transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, expected_timer_data, tx.data_out);
                        end else if (timer_has_unexpected_value) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x expected=0x%08x actual=0x%08x valid=%0b",
                                total_output_count, slave_idx, reg_idx, tx.addr, expected_timer_data, tx.data_out, tx.valid);
                        end else if (timer_has_invalid) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x (VALID not asserted, valid=%0b)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.valid);
                        end else if (timer_has_transfer_err) begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                        end else begin
                            $error("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER READ FAIL / SLAVE=%0d REG=%0d ADDR=0x%08x DATA_OUT=0x%08x (unexpected error status)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);                                
                        end 
                        $display("[SCOREBOARD]\tTimer Differences: Expected:0x%08x Actual:0x%08x Difference:%0d cycles Elapsed Time:%0t ns", 
                            expected_timer_data, tx.data_out, (expected_timer_data > tx.data_out) ? (expected_timer_data - tx.data_out) : (tx.data_out - expected_timer_data), elapsed);
                    end else begin
                        $display("[SCOREBOARD]\tTX#%0d (OUTPUT) TIMER PASS / SLAVE=%0d REG=%0d (expected=0x%08x actual=0x%08x) elapsed=%0t ns",
                            total_output_count, slave_idx, reg_idx, expected_timer_data, tx.data_out, elapsed);
                        read_pass_count++;
                    end
                end
            end
            slave_accesses[slave_idx]++;
            slave_rw_accesses[slave_idx][tx.rw]++; // Increment access count for this slave and rw type
        end
    endtask

    function void report(int enable_directed);
        $display("\n[SCOREBOARD] ===== FINAL REPORT (%0s) =====", (enable_directed ? "DIRECTED + RANDOM" : "RANDOM ONLY"));
        $display("[SCOREBOARD] WRITES: PASS=%0d FAIL=%0d", write_pass_count, write_fail_count);
        $display("[SCOREBOARD] READS:  PASS=%0d FAIL=%0d", read_pass_count, read_fail_count);
        $display("[SCOREBOARD] ILLEGAL TX: PASS=%0d FAIL=%0d", illegal_pass_count, illegal_fail_count);
        $display("[SCOREBOARD] SLAVE ACCESSES:");
        for (int i = 0; i < PARAMS::SLAVE_COUNT; i++) begin
            $display("[SCOREBOARD]   Slave %0d: %0d accesses (WRITES=%0d (ERRORS=%0d) READS=%0d (ERRORS=%0d))", 
                i, slave_accesses[i], slave_rw_accesses[i][1], slave_rw_errors[i][1], slave_rw_accesses[i][0], slave_rw_errors[i][0]);
        end
        $display("[SCOREBOARD] TOTAL ERRORS: %0d | ILLEGAL TX: %0d | TRANSACTIONS VERIFIED: %0d",
            error_count, illegal_count, total_output_count);
    endfunction

    function int get_score();
        return (write_pass_count + read_pass_count + illegal_pass_count);
    endfunction
endclass : SCOREBOARD