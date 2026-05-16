class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    // TLM Interfaces
    uvm_analysis_imp_mon_in #(apb_transaction, apb_scoreboard) scb_mon_in_port;
    uvm_analysis_imp_mon_out #(apb_transaction, apb_scoreboard) scb_mon_out_port;

    // FIFOs
    apb_transaction scb_mon_in_fifo[$];
    apb_transaction scb_mon_out_fifo[$];

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

    // Write Functions for Monitors
    function write_mon_in(apb_transaction t);
        scb_mon_in_fifo.push_back(t);
    endfunction

    function write_mon_out(apb_transaction t);
        scb_mon_out_fifo.push_back(t);
    endfunction

    // Golder Timer Helper Tasks and Functions
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

    // --- Constructor & Phases ---
    function new(string name = "apb_scoreboard", uvm_component parent);
        super.new(name, parent);

        `uvm_info("APB_SCB", "APB Scoreboard initialized", UVM_MEDIUM)
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        `uvm_info("APB_SCB", "Building Scoreboard components (analysis ports, FIFOs, and golden models)", UVM_MEDIUM)

        scb_mon_in_port  = new("scb_mon_in_port", this);
        scb_mon_out_port = new("scb_mon_out_port", this);

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

        `uvm_info("APB_SCB", "Configured Scoreboard components", UVM_MEDIUM)
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    // --- Run Phase ---
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info("APB_SCB", "Starting Scoreboard", UVM_MEDIUM)
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
            wait(scb_mon_in_fifo.size() != 0);
            tx = scb_mon_in_fifo.pop_front();
            total_input_count++;
            slave_idx = PARAMS::addr_to_slave_idx(tx.addr);
            reg_idx = PARAMS::addr_to_reg_idx(tx.addr);
            model_idx = (slave_idx < PARAMS::SLAVE_COUNT) ? slave_to_model_idx[slave_idx] : -1;
            
            if (tx.illegal) begin
                illegal_count++;
                `uvm_info("APB_SCB_IN", $sformatf("TX#%0d Illegal Transaction Acknowledged: ADDR=0x%08x SLAVE=%0d REG=%0d", total_input_count, tx.addr, slave_idx, reg_idx), UVM_HIGH)
            end
            else if (tx.rw) begin 
                if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
                    golden_mem[model_idx][reg_idx] = tx.data_in;
                    `uvm_info("APB_SCB_IN", $sformatf("TX#%0d Memory Write Registered: SLAVE=%0d REG=%0d ADDR=0x%08x DATA=0x%08x", total_input_count, slave_idx, reg_idx, tx.addr, tx.data_in), UVM_HIGH)
                end 
                else if (slave_idx < PARAMS::SLAVE_COUNT && PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
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
            wait(scb_mon_out_fifo.size() != 0);
            tx = scb_mon_out_fifo.pop_front();
            total_output_count++;
            slave_idx = PARAMS::addr_to_slave_idx(tx.addr);
            reg_idx = PARAMS::addr_to_reg_idx(tx.addr);
            model_idx = (slave_idx < PARAMS::SLAVE_COUNT) ? slave_to_model_idx[slave_idx] : -1;

            if (tx.illegal) begin
                // --- ILLEGAL TRANSACTION CHECK ---
                // Only check: transfer_status should be asserted (1)

                if (tx.transfer_status != 1'b1) begin
                    illegal_fail_count++;
                    `uvm_error("APB_SCB_OUT", $sformatf("TX#%0d ILLEGAL FAIL: transfer_status=%0b (expected 1)", total_output_count, tx.transfer_status))
                end else begin
                    illegal_pass_count++;
                    `uvm_info("APB_SCB_OUT", $sformatf("TX#%0d ILLEGAL PASS: transfer_status=%0b", total_output_count, tx.transfer_status), UVM_HIGH)
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
    function void report_phase(uvm_phase phase);
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