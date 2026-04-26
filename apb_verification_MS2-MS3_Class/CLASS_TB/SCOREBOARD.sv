class SCOREBOARD;
	mailbox mon_in2sb;
	mailbox mon_out2scb;

	int total_tests;
	int mem_slave_count;
	int read_pass_count;
	int read_fail_count;
	int write_pass_count;
	int write_fail_count;
	int total_input_count;
	int total_output_count;
	int error_count;

	localparam int REG_DEPTH = (1 << PARAMS::REG_NUM);
	bit [PARAMS::DATA_WIDTH-1:0] golden_mem[][];
	bit [PARAMS::DATA_WIDTH-1:0] timer_last_val[PARAMS::SLAVE_COUNT][]; // Tracks last written timer value
	int slave_to_model_idx[PARAMS::SLAVE_COUNT];

	function new(mailbox mon_in2sb, mailbox mon_out2scb, int total_tests);
		int model_idx;
		this.mon_in2sb = mon_in2sb;
		this.mon_out2scb = mon_out2scb;
		this.total_tests = total_tests;
		this.read_pass_count = 0;
		this.read_fail_count = 0;
		this.write_pass_count = 0;
		this.write_fail_count = 0;
		this.total_input_count = 0;
		this.total_output_count = 0;
		this.error_count = 0;

		// Initialize slave to model mapping
		foreach (slave_to_model_idx[i]) begin
			slave_to_model_idx[i] = -1;
		end

		// Count memory-mapped slaves and initialize golden model
		mem_slave_count = 0;
		foreach (PARAMS::PERIPH_TYPE[i]) begin
			if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_MEM) begin
				slave_to_model_idx[i] = mem_slave_count;
				mem_slave_count++;
			end
			// Initialize timer tracking arrays
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
	endfunction

	task start();
		$display("[SCOREBOARD] STARTED");
		
		fork
			// --------------------------------------------------------
			// Input Monitor Processing (Update Golden Model)
			// --------------------------------------------------------
			forever begin
				TRANSACTION tx;
				int slave_idx;
				int reg_idx;
				int model_idx;

				mon_in2sb.get(tx);
				total_input_count++;
				slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
				reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
				model_idx = slave_to_model_idx[slave_idx];

				$display("[SCOREBOARD] IN  #%0d: slave=%0d reg=%0d addr=0x%08x rw=%b data_in=0x%08x", 
					total_input_count, slave_idx, reg_idx, tx.addr, tx.rw, tx.data_in);

				if (tx.rw) begin // Write transaction
					if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
						golden_mem[model_idx][reg_idx] = tx.data_in;
						$display("[SCOREBOARD] MODEL WRITE: mem[%0d][%0d] <= 0x%08x", model_idx, reg_idx, tx.data_in);
					end 
					else if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
						timer_last_val[slave_idx][reg_idx] = tx.data_in;
						$display("[SCOREBOARD] MODEL WRITE: timer[%0d][%0d] <= 0x%08x", slave_idx, reg_idx, tx.data_in);
					end
				end
			end

			// --------------------------------------------------------
			// Output Monitor Processing (Check DUT outputs)
			// --------------------------------------------------------
			forever begin
				TRANSACTION tx;
				int slave_idx;
				int reg_idx;
				int model_idx;
				bit [PARAMS::DATA_WIDTH-1:0] expected_data;

				mon_out2scb.get(tx);
				total_output_count++;
				slave_idx = tx.addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
				reg_idx = tx.addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
				model_idx = slave_to_model_idx[slave_idx];

				if (tx.rw) begin // Write Completion Check
					if (tx.transfer_status == 1 || tx.valid == 1) begin
						write_fail_count++;
						error_count++;
						$error("[SCOREBOARD] WRITE ERROR #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x",
							total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
					end else begin
						write_pass_count++;
						$display("[SCOREBOARD] OUT #%0d WRITE: slave=%0d reg=%0d addr=0x%08x data=0x%08x",
							total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
					end
				end 
				else begin // Read Completion Check
					if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_MEM) begin
						expected_data = golden_mem[model_idx][reg_idx];
						if ((tx.valid !== 1'b1) || (tx.data_out !== expected_data)) begin
							read_fail_count++;
							error_count++;
							$error("[SCOREBOARD] READ MISMATCH #%0d: slave=%0d reg=%0d addr=0x%08x expected=0x%08x actual=0x%08x valid=%0b",
								total_output_count, slave_idx, reg_idx, tx.addr, expected_data, tx.data_out, tx.valid);
						end else begin
							read_pass_count++;
							$display("[SCOREBOARD] OUT #%0d READ OK: slave=%0d reg=%0d addr=0x%08x data=0x%08x valid=1",
								total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
						end
					end
					else if (PARAMS::PERIPH_TYPE[slave_idx] == PARAMS::TYPE_TIMER) begin
						// Timer check: Value should be less than or equal to what was written, and valid must be high
						if ((tx.valid === 1'b1) && (tx.data_out <= timer_last_val[slave_idx][reg_idx])) begin
							read_pass_count++;
							$display("[SCOREBOARD] OUT #%0d READ TIMER OK: slave=%0d reg=%0d data=0x%08x (Expected <= 0x%08x) valid=1",
								total_output_count, slave_idx, reg_idx, tx.data_out, timer_last_val[slave_idx][reg_idx]);
						end else begin
							read_fail_count++;
							error_count++;
							$error("[SCOREBOARD] READ TIMER FAIL #%0d: slave=%0d reg=%0d actual=0x%08x (Expected <= 0x%08x) valid=%0b",
								total_output_count, slave_idx, reg_idx, tx.data_out, timer_last_val[slave_idx][reg_idx], tx.valid);
						end
					end
				end
			end
		join_none
	endtask

	function void report();
		$display("[SCOREBOARD] Report: writes pass=%0d fail=%0d | reads pass=%0d fail=%0d | errors=%0d | total outputs=%0d",
			write_pass_count, write_fail_count, read_pass_count, read_fail_count, error_count, total_output_count);
	endfunction

	function int get_score();
		return (write_pass_count + read_pass_count);
	endfunction

endclass : SCOREBOARD