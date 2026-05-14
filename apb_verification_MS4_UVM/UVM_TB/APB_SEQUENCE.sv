/* UVM_SEQUENCES.sv
	This holds the classes used for the sequences in the UVM testbench
		- Base Sequence Class
        - Directed Sequence Classes
*/

class transaction_seq extends uvm_sequence;

	`uvm_object_utils(transaction_seq)

	apb_transaction tx;

	function new(string name = "transaction_seq");
		super.new(name);
		`uvm_info("TRANSACTION_SEQ", "Sequence created", UVM_HIGH)
	endfunction

	task body();
		tx = apb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize()) begin
            `uvm_fatal("TRANSACTION_SEQ", "Failed to randomize transaction")
        end
        finish_item(tx);
	endtask

endclass : transaction_seq

class apb_directed_seq_base extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_directed_seq_base)

    function new(string name = "apb_directed_seq_base");
        super.new(name);
    endfunction

    protected task send_direct_tx(
        bit rw_val,
        bit [PARAMS::SLAVE_COUNT-1:0] slave_sel_val,
        bit [PARAMS::REG_NUM-1:0] reg_sel_val,
        bit [PARAMS::DATA_WIDTH-1:0] data_in_val,
        bit use_post_randomize = 1'b1,
        bit [PARAMS::ADDR_WIDTH-1:0] addr_val = '0,
        bit illegal_val = 1'b0
    );
        apb_transaction tx;

        tx = apb_transaction::type_id::create("tx");
        start_item(tx);

        tx.rw = rw_val;
        tx.slave_sel = slave_sel_val;
        tx.reg_sel = reg_sel_val;
        tx.data_in = data_in_val;

        if (use_post_randomize) begin
            tx.post_randomize();
        end else begin
            tx.addr = addr_val;
        end

        tx.illegal = illegal_val;
        finish_item(tx);
    endtask
endclass : apb_directed_seq_base

class apb_reset_check_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_reset_check_seq)

    function new(string name = "apb_reset_check_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_RESET_SEQ", "Starting Reset Check sequence", UVM_LOW)

        for (int s = 0; s < 2; s++) begin
            for (int r = 0; r < 32; r++) begin
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
            end
        end

        `uvm_info("APB_RESET_SEQ", "Reset Check sequence complete", UVM_LOW)
    endtask
endclass : apb_reset_check_seq

class apb_data_integrity_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_data_integrity_seq)

    function new(string name = "apb_data_integrity_seq");
        super.new(name);
    endfunction

    task body();
        bit [PARAMS::DATA_WIDTH-1:0] test_patterns[4] = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555};

        `uvm_info("APB_DATA_SEQ", "Starting Data Integrity sequence", UVM_LOW)

        foreach (test_patterns[p]) begin
            for (int s = 0; s < 3; s++) begin
                send_direct_tx(1'b1, s, 0, test_patterns[p]);
                send_direct_tx(1'b0, s, 0, 32'h0000_0000);
            end
        end

        `uvm_info("APB_DATA_SEQ", "Data Integrity sequence complete", UVM_LOW)
    endtask
endclass : apb_data_integrity_seq

class apb_stuck_bits_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_stuck_bits_seq)

    function new(string name = "apb_stuck_bits_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_STUCK_SEQ", "Starting Stuck Bits sequence", UVM_LOW)

        for (int s = 0; s < 2; s++) begin
            for (int r = 0; r < 32; r++) begin
                send_direct_tx(1'b1, s, r, 32'hFFFFFFFF);
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
                send_direct_tx(1'b1, s, r, 32'h0000_0000);
                send_direct_tx(1'b0, s, r, 32'h0000_0000);
            end
        end

        `uvm_info("APB_STUCK_SEQ", "Stuck Bits sequence complete", UVM_LOW)
    endtask
endclass : apb_stuck_bits_seq

class apb_timer_validation_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_timer_validation_seq)

    function new(string name = "apb_timer_validation_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_TIMER_SEQ", "Starting Timer Validation sequence", UVM_LOW)

        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 0, 32'h0000_0005);

        for (int i = 0; i < 6; i++) begin
            send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_0, 0, 32'h0000_0000);
        end

        send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_2, 0, 32'h0000_0000);

        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_0FFF);
        send_direct_tx(1'b0, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_0000);
        send_direct_tx(1'b1, PARAMS::ADDR_SLAVE_2, 1, 32'h0000_00AA);

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

        `uvm_info("APB_TIMER_SEQ", "Timer Validation sequence complete", UVM_LOW)
    endtask
endclass : apb_timer_validation_seq

class apb_illegal_tx_seq extends apb_directed_seq_base;
    `uvm_object_utils(apb_illegal_tx_seq)

    function new(string name = "apb_illegal_tx_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_ILLEGAL_SEQ", "Starting Illegal Transaction sequence", UVM_LOW)

        send_direct_tx(
            1'b1,
            PARAMS::SLAVE_COUNT,
            0,
            32'hCAFEBABE,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::SLAVE_COUNT, 0)),
            .illegal_val(1'b1)
        );

        send_direct_tx(
            1'b1,
            PARAMS::ADDR_SLAVE_2,
            0,
            32'hFACE_FEED,
            .use_post_randomize(1'b0),
            .addr_val(apb_transaction::build_addr(PARAMS::ADDR_SLAVE_2, 0) | {{(PARAMS::ADDR_WIDTH-2){1'b0}}, 2'b11}),
            .illegal_val(1'b1)
        );

        `uvm_info("APB_ILLEGAL_SEQ", "Illegal Transaction sequence complete", UVM_LOW)
    endtask
endclass : apb_illegal_tx_seq