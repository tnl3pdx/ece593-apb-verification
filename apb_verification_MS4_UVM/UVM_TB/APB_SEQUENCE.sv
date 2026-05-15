/* UVM_SEQUENCES.sv
	This holds the classes used for the sequences in the UVM testbench
        - Random Sequence Class
		- Base Directed Sequence Class
        - Children Directed Sequence Classes
            - Reset Check Sequence
            - Data Integrity Sequence
            - Stuck Bits Sequence
            - Timer Validation Sequence
            - Illegal Transaction Sequence
*/

class rand_seq extends uvm_sequence;
	`uvm_object_utils(rand_seq)

	apb_transaction tx;

	function new(string name = "rand_seq");
		super.new(name);
		`uvm_info("RAND_SEQ", "Random sequence initialized", UVM_HIGH)
	endfunction

	task body();
		tx = apb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize()) begin
            `uvm_fatal("RAND_SEQ", "Failed to randomize transaction")
        end
        finish_item(tx);
	endtask

endclass : rand_seq

class apb_directed_seq_base extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_directed_seq_base)

    function new(string name = "apb_directed_seq_base");
        super.new(name);
    endfunction

    protected task send_direct_tx(
        bit rw_val,                                     // RW Bit
        bit [PARAMS::SLAVE_COUNT-1:0] slave_sel_val,    // Slave Select
        bit [PARAMS::REG_NUM-1:0] reg_sel_val,          // Register Select
        bit [PARAMS::DATA_WIDTH-1:0] data_in_val,       // Data Input
        bit use_post_randomize = 1'b1,                  // Use post_randomize
        bit [PARAMS::ADDR_WIDTH-1:0] addr_val = '0,     // Direct Address (if not using post_randomize)
        bit illegal_val = 1'b0                          // Illegal flag
    );
        apb_transaction tx;

        tx = apb_transaction::type_id::create("tx");
        start_item(tx);

        tx.rw = rw_val;
        tx.slave_sel = slave_sel_val;
        tx.reg_sel = reg_sel_val;
        tx.data_in = data_in_val;

        // If use_post_randomize is set, call post_randomize to compute the address and set illegal flag to default 0
        // Else, directly set address 
        if (use_post_randomize) begin
            tx.post_randomize();
        end else begin
            tx.addr = addr_val;
            tx.illegal = illegal_val;
        end

        finish_item(tx);
    endtask
endclass : apb_directed_seq_base

class apb_reset_check_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_reset_check_seq)

    function new(string name = "apb_reset_check_seq");
        super.new(name);
        `uvm_info("APB_RESET_SEQ", "APB Reset Check sequence initialized", UVM_MEDIUM)
    endfunction

    task body();
        `uvm_info("APB_RESET_SEQ", "Starting Reset Check sequence", UVM_MEDIUM)

		// =========================================================
		// FV-001 Reset Check
		//  Sequentially read all 32 registers from Slave 0 and Slave 1
		//  before any writes can corrupt them.
		// =========================================================
        for (int s = 0; s < 2; s++) begin
            for (int r = 0; r < 32; r++) begin
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
            end
        end

        `uvm_info("APB_RESET_SEQ", "Reset Check sequence complete", UVM_MEDIUM)
    endtask
endclass : apb_reset_check_seq

class apb_data_integrity_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_data_integrity_seq)

    function new(string name = "apb_data_integrity_seq");
        super.new(name);
        `uvm_info("APB_DATA_SEQ", "APB Data Integrity sequence initialized", UVM_MEDIUM)
    endfunction

    task body();
        bit [PARAMS::DATA_WIDTH-1:0] test_patterns[4] = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555};

        `uvm_info("APB_DATA_SEQ", "Starting Data Integrity sequence", UVM_MEDIUM)

		// =========================================================
		// FV-004 Data Integrity Check
		//  Write specific patterns to a register, and immediately read
		//  them back to hit the Write x Read cross coverage bins.
		// =========================================================

        foreach (test_patterns[p]) begin
            for (int s = 0; s < 3; s++) begin
                send_direct_tx(1'b1, s, 0, test_patterns[p]);
                send_direct_tx(1'b0, s, 0, 32'h0000_0000);
            end
        end

        `uvm_info("APB_DATA_SEQ", "Data Integrity sequence complete", UVM_MEDIUM)
    endtask
endclass : apb_data_integrity_seq

class apb_stuck_bits_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_stuck_bits_seq)

    function new(string name = "apb_stuck_bits_seq");
        super.new(name);
        `uvm_info("APB_STUCK_SEQ", "APB Stuck Bits sequence initialized", UVM_MEDIUM)
    endfunction

    task body();
        `uvm_info("APB_STUCK_SEQ", "Starting Stuck Bits sequence", UVM_MEDIUM)

		// =========================================================
		// Stuck bits and Boundary Checks
		//  Switch all mem registers to 0xFFFFFFFF, then read them, 
		//  then write 0x00000000 and read again to check for stuck bits.
        // =========================================================

        for (int s = 0; s < 2; s++) begin
            for (int r = 0; r < 32; r++) begin
                send_direct_tx(1'b1, s, r, 32'hFFFFFFFF);
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
                send_direct_tx(1'b1, s, r, 32'h0000_0000);
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
            end
        end

        `uvm_info("APB_STUCK_SEQ", "Stuck Bits sequence complete", UVM_MEDIUM)
    endtask
endclass : apb_stuck_bits_seq

class apb_timer_validation_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_timer_validation_seq)

    function new(string name = "apb_timer_validation_seq");
        super.new(name);
        `uvm_info("APB_TIMER_SEQ", "APB Timer Validation sequence initialized", UVM_MEDIUM)
    endfunction

    task body();
        `uvm_info("APB_TIMER_SEQ", "Starting Timer Validation sequence", UVM_MEDIUM)

        // =========================================================
		// Timer Validation Sequences
		// =========================================================

		// --- Floor at Zero Check ---
		// Write a small value (5) to Timer 0, wait for it to expire, then read.
        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 0, 32'h0000_0005);

        // Insert dummy reads to other slaves to pass time (> 5 cycles)
        for (int i = 0; i < 6; i++) begin
            send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_0, 0, 32'h0000_0000);
        end

        // Read Timer 0 back - Scoreboard should expect 0x0
        send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_2, 0, 32'h0000_0000);

        // --- Mid-Countdown Override Check ---
		// Write a large value to Timer 1, then immediately overwrite it.
        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_0FFF);

        // Read to advance time slightly
        send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_0000);

        // Overwrite while still counting
        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_00AA);


        // --- Out-of-Bounds Indexing Check ---
		// Attempt to write and read a timer register outside the valid range.
        send_direct_tx(
            1'b1,
            PARAMS::ADDR_SLAVE_2,
            PARAMS::NUM_TIMERS,
            32'hDEAD_BEEF,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::ADDR_SLAVE_2, PARAMS::NUM_TIMERS)),
            .illegal_val(1'b1)
        );
        send_direct_tx(
            1'b0,
            PARAMS::ADDR_SLAVE_2,
            PARAMS::NUM_TIMERS,
            32'h0000_0000,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::ADDR_SLAVE_2, PARAMS::NUM_TIMERS)),
            .illegal_val(1'b1)
        );

        `uvm_info("APB_TIMER_SEQ", "Timer Validation sequence complete", UVM_MEDIUM)
    endtask
endclass : apb_timer_validation_seq

class apb_illegal_tx_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_illegal_tx_seq)

    function new(string name = "apb_illegal_tx_seq");
        super.new(name);
        `uvm_info("APB_ILLEGAL_SEQ", "APB Illegal Transaction sequence initialized", UVM_MEDIUM)
    endfunction

    task body();
        `uvm_info("APB_ILLEGAL_SEQ", "Starting Illegal Transaction sequence", UVM_MEDIUM)

		// =========================================================
		// Illegal Transaction Checks
		// =========================================================

		// --- Invalid Slave Selection Check ---
		// Target a slave index outside the configured slave range.
        send_direct_tx(
            1'b1,
            PARAMS::SLAVE_COUNT,
            0,
            32'hCAFEBABE,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::SLAVE_COUNT, 0)),
            .illegal_val(1'b1)
        );

		// --- Unaligned Access Check ---
		// Keep the address structure valid, but break word alignment.
        send_direct_tx(
            1'b1,
            PARAMS::ADDR_SLAVE_2,
            0,
            32'hFACE_FEED,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::ADDR_SLAVE_2, 0) | {{(PARAMS::ADDR_WIDTH-2){1'b0}}, 2'b11}),
            .illegal_val(1'b1)
        );

        `uvm_info("APB_ILLEGAL_SEQ", "Illegal Transaction sequence complete", UVM_MEDIUM)
    endtask
endclass : apb_illegal_tx_seq