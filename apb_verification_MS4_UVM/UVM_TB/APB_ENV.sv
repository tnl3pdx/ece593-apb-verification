class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    // Agent, Scoreboard, and Coverage instances
    apb_agent      agnt;
    apb_scoreboard scb;
    apb_coverage   cov; //coverage function

    // Constructor
    function new(string name = "apb_env", uvm_component parent);
        super.new(name, parent);
        `uvm_info("APB_ENV", "APB Environment initialized", UVM_MEDIUM)
    endfunction

    // Build phase: Instantiate components
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        `uvm_info("APB_ENV", "Initializing components", UVM_MEDIUM)

        // Instantiate agent, scoreboard, and coverage collector
        agnt = apb_agent::type_id::create("agnt", this);
        scb  = apb_scoreboard::type_id::create("scb", this);
        cov  = apb_coverage::type_id::create("cov", this); // Build the coverage component
        
        `uvm_info("APB_ENV", "Agent, Scoreboard, and Coverage components initialized", UVM_MEDIUM)
    endfunction

    // Connect phase: Connect agent's monitor to the scoreboard and coverage
   function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect to Scoreboard
        agnt.mon.ap_in.connect(scb.mon_in_export);
        agnt.mon.ap_out.connect(scb.mon_out_export);

        // Connect to Coverage (Both Interfaces)
        agnt.mon.ap_in.connect(cov.cov_export_in);
        agnt.mon.ap_out.connect(cov.cov_export_out);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask

endclass : apb_env