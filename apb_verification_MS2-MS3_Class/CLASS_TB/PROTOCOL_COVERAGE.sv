class PROTOCOL_COVERAGE;
	// Parameterized virtual interface
	virtual apb_bus_if #(.DATA_WIDTH(PARAMS::DATA_WIDTH), .ADDR_WIDTH(PARAMS::ADDR_WIDTH), .SLAVE_COUNT(PARAMS::SLAVE_COUNT)) vif;
	
	typedef enum int { IDLE=0, SETUP=1, ACCESS=2 } apb_state_e;
	apb_state_e current_state;
	bit current_write;

	// =========================================================
	// FV-002: APB Phases Functional Coverage
	// =========================================================
	covergroup cg_APB_phases;
		option.per_instance = 1;
		option.name = "FV-002_APB_Phases";

		// Track specific protocol state transitions
		cp_state_trans: coverpoint current_state {
			bins idle_to_setup   = (IDLE => SETUP);
			bins setup_to_access = (SETUP => ACCESS);
			bins access_to_idle  = (ACCESS => IDLE);
			bins access_to_setup = (ACCESS => SETUP); // Back-to-back transactions
		}
		
		// Track Read vs Write
		cp_rw: coverpoint current_write {
			bins read  = {0};
			bins write = {1};
		}
		
		// Cross the transitions with the direction
		cx_phase_dir: cross cp_state_trans, cp_rw;
	endgroup

	function new(virtual apb_bus_if #(.DATA_WIDTH(PARAMS::DATA_WIDTH), .ADDR_WIDTH(PARAMS::ADDR_WIDTH), .SLAVE_COUNT(PARAMS::SLAVE_COUNT)) vif);
		this.vif = vif;
		cg_APB_phases = new();
		current_state = IDLE;
	endfunction

	task start();
		$display("[PROTOCOL_COVERAGE] STARTED");
		forever begin
			@(posedge vif.clk);
			if (!vif.rst_n) begin
				current_state = IDLE;
			end else begin
				// Decode the APB State Machine purely from the bus signals
				if ((|vif.psel) == 0) begin
					current_state = IDLE;
				end else if (vif.penable == 0) begin
					current_state = SETUP;
					current_write = vif.pwrite; // Capture direction during setup
				end else begin
					current_state = ACCESS;
					current_write = vif.pwrite;
				end
				
				// Sample the covergroup on every clock cycle
				cg_APB_phases.sample();
			end
		end
	endtask
endclass : PROTOCOL_COVERAGE