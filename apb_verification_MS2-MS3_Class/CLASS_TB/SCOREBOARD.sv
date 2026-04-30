class SCOREBOARD;
    mailbox mon_in2sb;
    mailbox mon_out2scb;

    int total_tests;
    int mem_slave_count;
    int read_pass_count, read_fail_count;
    int write_pass_count, write_fail_count;
    int total_input_count, total_output_count;
    int error_count;

    localparam int REG_DEPTH = (1 << PARAMS::REG_NUM);
    bit [PARAMS::DATA_WIDTH-1:0] golden_mem[][];
    bit [PARAMS::DATA_WIDTH-1:0] timer_last_val[PARAMS::SLAVE_COUNT][];
    int slave_to_model_idx[PARAMS::SLAVE_COUNT];

    // =========================================================
    // FV-001 & FV-004 Coverage Variables & Groups
    // =========================================================
    int cov_slave_idx, cov_reg_idx;
    bit cov_rw;
    bit [PARAMS::DATA_WIDTH-1:0] cov_data;

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

    function new(mailbox mon_in2sb, mailbox mon_out2scb, int total_tests);
        int model_idx;
        this.mon_in2sb = mon_in2sb;
        this.mon_out2scb = mon_out2scb;
        this.total_tests = total_tests;
        this.read_pass_count = 0; this.read_fail_count = 0;
        this.write_pass_count = 0; this.write_fail_count = 0;
        this.total_input_count = 0; this.total_output_count = 0;
        this.error_count = 0;

        foreach (slave_to_model_idx[i]) slave_to_model_idx[i] = -1;
        mem_slave_count = 0;
        foreach (PARAMS::PERIPH_TYPE[i]) begin
            if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_MEM) begin
                slave_to_model_idx[i] = mem_slave_count;
                mem_slave_count++;
            end
            if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_TIMER) begin
                timer_last_val[i] = new[REG_DEPTH];
                foreach(timer_last_val[i][j]) timer_last_val[i][j] = '0;
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
    endfunction

	task start();
		$display("[SCOREBOARD] STARTED");
		fork
			get_input();
			get_output();
		join_none
	endtask
        
	task get_input();
            // INPUT MONITOR PROCESSING
            TRANSACTION tx;
            int slave_idx, reg_idx, model_idx;           
            
            forever begin

                mon_in2sb.get(tx);
                total_input_count++;
                slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
                reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
                model_idx = slave_to_model_idx[slave_idx];

                if (tx.rw) begin // Write transaction
                    // Sample FV-004 Coverage for Writes
                    cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_in;
                    cg_data_integrity.sample();

                    if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                        golden_mem[model_idx][reg_idx] = tx.data_in;
                            $display("[SCOREBOARD] INPUT: WRITE slave=%0d reg=%0d addr=0x%08x data=0x%08x",
                            slave_idx, reg_idx, tx.addr, tx.data_in);
                    end 
                    else if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                        timer_last_val[slave_idx][reg_idx] = tx.data_in;
                            $display("[SCOREBOARD] INPUT: WRITE (TIMER) slave=%0d reg=%0d addr=0x%08x data=0x%08x",
                                slave_idx, reg_idx, tx.addr, tx.data_in);
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
                model_idx = slave_to_model_idx[slave_idx];

                if (tx.rw) begin 
                    if (tx.transfer_status == 1 || tx.valid == 1) begin
                        write_fail_count++; error_count++;
                        if (tx.valid === 1'b1) begin
                            $error("[SCOREBOARD] OUTPUT: WRITE FAIL #%0d: slave=%0d reg=%0d ADDR=0x%08x data=0x%08x valid=%0b",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out, tx.valid);
                        end else begin
                            $error("[SCOREBOARD] OUTPUT: WRITE FAIL #%0d: slave=%0d reg=%0d ADDR=0x%08x data=0x%08x (transfer error)",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                        end
                    end else begin
                        write_pass_count++;
                        $display("[SCOREBOARD] OUTPUT: WRITE PASS #%0d slave=%0d reg=%0d ADDR=0x%08x data=0x%08x",
                            total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                    end
                end 
                else begin // Read Completion Check
                    // Sample FV-001 and FV-004 Coverage for Reads
                    cov_slave_idx = slave_idx; cov_reg_idx = reg_idx; cov_rw = tx.rw; cov_data = tx.data_out;
                    cg_data_integrity.sample();
                    cg_reset.sample();

                    if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                        expected_data = golden_mem[model_idx][reg_idx];
                        if ((tx.valid !== 1'b1) || (tx.data_out !== expected_data)) begin
                            read_fail_count++; error_count++;
                            if ((tx.data_out !== expected_data)) begin
                                    $error("[SCOREBOARD] OUTPUT: READ FAIL #%0d slave=%0d reg=%0d ADDR=0x%08x expected=0x%08x actual=0x%08x valid=%0b",
                                        total_output_count, slave_idx, reg_idx, tx.addr, expected_data, tx.data_out, tx.valid);
                                end else begin
                                    $error("[SCOREBOARD] OUTPUT: READ FAIL #%0d slave=%0d reg=%0d ADDR=0x%08x (VALID not asserted, valid=%0b)",
                                        total_output_count, slave_idx, reg_idx, tx.addr, tx.valid);
                                end
                        end else begin
                            read_pass_count++;
                            $display("[SCOREBOARD] OUTPUT: READ PASS #%0d slave=%0d reg=%0d ADDR=0x%08x DATA=0x%08x",
                                total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                        end
                    end
                    else if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
                        if ((tx.valid !== 1'b1)) begin  // TODO: Add expected value check once timer behavior is fully defined and modeled
                            read_fail_count++; error_count++;
                            if (tx.valid !== 1'b1) begin
                                $error("[SCOREBOARD] TIMER READ ERROR #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x (invalid transfer, valid=%0b)",
                                    total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out, tx.valid);
                            end else begin
                                $error("[SCOREBOARD] TIMER PROTOCOL ERROR #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x (unexpected error status)",
                                    total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
                            end
                        end else begin
                            read_pass_count++;
                        end
                    end
                end
            end
    endtask

    function void report();
        $display("[SCOREBOARD] ===== FINAL REPORT =====");
        $display("[SCOREBOARD] WRITES: PASS=%0d FAIL=%0d", write_pass_count, write_fail_count);
        $display("[SCOREBOARD] READS:  PASS=%0d FAIL=%0d", read_pass_count, read_fail_count);
        $display("[SCOREBOARD] TOTAL ERRORS: %0d | TRANSACTIONS VERIFIED: %0d",
            error_count, total_output_count);
    endfunction

    function int get_score();
        return (write_pass_count + read_pass_count);
    endfunction
endclass : SCOREBOARD