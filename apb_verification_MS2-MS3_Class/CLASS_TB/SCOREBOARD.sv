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
				mem_slave_count++;
			end
		end

		// Initialize golden memory model for each memory-mapped slave
		golden_mem = new[mem_slave_count];
		model_idx = 0;
		foreach (PARAMS::PERIPH_TYPE[i]) begin
			if (PARAMS::PERIPH_TYPE[i] == PARAMS::TYPE_MEM) begin
				slave_to_model_idx[i] = model_idx;
				golden_mem[model_idx] = new[REG_DEPTH];
				foreach (golden_mem[model_idx][j]) begin
					golden_mem[model_idx][j] = '0;
				end
				model_idx++;
			end
		end
	endfunction

	function automatic int decode_slave_index(logic [PARAMS::ADDR_WIDTH-1:0] addr);
		return addr[PARAMS::ADDR_WIDTH-1 -: PARAMS::ADDR_MSB_len];
	endfunction

	function automatic int decode_reg_index(logic [PARAMS::ADDR_WIDTH-1:0] addr);
		return addr[PARAMS::WORD_LEN +: PARAMS::REG_NUM];
	endfunction

	function automatic int get_model_index(int slave_idx);
		if ((slave_idx < 0) || (slave_idx >= PARAMS::SLAVE_COUNT)) begin
			return -1;
		end
		return slave_to_model_idx[slave_idx];
	endfunction

	function bit is_done();
		return total_output_count >= total_tests;
	endfunction

	function int get_score();
		return read_pass_count + write_pass_count;
	endfunction

	function void report();
		$display("[SCOREBOARD] Report: writes pass=%0d fail=%0d | reads pass=%0d fail=%0d | errors=%0d | total outputs=%0d",
			write_pass_count, write_fail_count, read_pass_count, read_fail_count, error_count, total_output_count);
	endfunction

	task start();
		$display("[SCOREBOARD] STARTED");
		fork
			get_input();
			get_output();
		join_none
	endtask

	task get_input();
		TRANSACTION tx;
		int slave_idx;
		int model_idx;
		int reg_idx;

		forever begin
			mon_in2sb.get(tx);
			total_input_count++;
			slave_idx = decode_slave_index(tx.addr);
			model_idx = get_model_index(slave_idx);
			reg_idx = decode_reg_index(tx.addr);

			$display("[SCOREBOARD] IN  #%0d: slave=%0d reg=%0d addr=0x%08x rw=%b data_in=0x%08x",
				total_input_count, slave_idx, reg_idx, tx.addr, tx.rw, tx.data_in);

			if (model_idx < 0) begin
				$display("[SCOREBOARD] INFO: peripheral at slave %0d is not modeled", slave_idx);
			end else if (tx.rw) begin
				golden_mem[model_idx][reg_idx] = tx.data_in;
				$display("[SCOREBOARD] MODEL WRITE: mem[%0d][%0d] <= 0x%08x", model_idx, reg_idx, tx.data_in);
			end
		end
	endtask

	task get_output();
		TRANSACTION tx;
		int slave_idx;
		int model_idx;
		int reg_idx;
		bit [PARAMS::DATA_WIDTH-1:0] expected_data;

		forever begin
			mon_out2scb.get(tx);
			total_output_count++;
			slave_idx = decode_slave_index(tx.addr);
			model_idx = get_model_index(slave_idx);
			reg_idx = decode_reg_index(tx.addr);

			if (model_idx < 0) begin
				$display("[SCOREBOARD] OUT #%0d: slave=%0d reg=%0d addr=0x%08x rw=%b data=0x%08x (unmodeled peripheral)",
					total_output_count, slave_idx, reg_idx, tx.addr, tx.rw, tx.data_out);
			end else if (tx.rw) begin
				if (tx.transfer_status == 1 || tx.valid === 1'b1) begin
					write_fail_count++;
					error_count++;
					if (tx.valid === 1'b1) begin
						$error("[SCOREBOARD] WRITE ERROR (VALID ASSERTED) #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x (invalid transfer, valid=%0b)",
							total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out, tx.valid);
					end else begin
						$error("[SCOREBOARD] WRITE ERROR #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x",
							total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
					end
				end else begin
					write_pass_count++;
					$display("[SCOREBOARD] OUT #%0d WRITE: slave=%0d reg=%0d addr=0x%08x data=0x%08x",
						total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out);
				end
			end else begin
				expected_data = golden_mem[model_idx][reg_idx];
				if ((tx.valid !== 1'b1) || (tx.data_out !== expected_data)) begin
					read_fail_count++;
					error_count++;
					if (tx.data_out !== expected_data) begin
						$error("[SCOREBOARD] READ MISMATCH #%0d: slave=%0d reg=%0d addr=0x%08x expected=0x%08x actual=0x%08x valid=%0b",
							total_output_count, slave_idx, reg_idx, tx.addr, expected_data, tx.data_out, tx.valid);
					end else begin
						$error("[SCOREBOARD] READ ERROR #%0d: slave=%0d reg=%0d addr=0x%08x data=0x%08x (invalid transfer, valid=%0b)",
							total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out, tx.valid);
					end
				end else begin
					read_pass_count++;
					$display("[SCOREBOARD] OUT #%0d READ OK: slave=%0d reg=%0d addr=0x%08x data=0x%08x valid=%0b",
						total_output_count, slave_idx, reg_idx, tx.addr, tx.data_out, tx.valid);
				end
			end
		end
	endtask

endclass : SCOREBOARD