`include "CLASS_TB/CLASS_TB_INCLUDES.sv"

module APB_TOP;
    // Clock and Reset Signals
    logic pclk, prstn;

    // Reset and clock generation
    initial begin
        prstn = 1; // Release reset
        @(posedge pclk)
        prstn = 0;
        @(posedge pclk)
        prstn = 1; // Release reset
        @(posedge pclk);
    end
    
    initial begin
        pclk = 0;
        forever #(PARAMS::CLK_PERIOD/2) pclk = ~pclk;
    end

    // Interface instances
    apb_external_if ext_if(.clk(pclk), .rst_n(prstn));

    // Class Based Environment
    TEST #(
        .NUM_TESTS(1000),
        .ENABLE_DIRECTED(1)
    ) test (
        .ext_if(ext_if),
        .bus_if(apb_sys.bus_if)
    );

    // DUV instantiation
    APB_SYS_DUT #(
        .DATA_WIDTH(PARAMS::DATA_WIDTH),
        .ADDR_WIDTH(PARAMS::ADDR_WIDTH),
        .REG_NUM(PARAMS::REG_NUM),
        .MASTER_COUNT(PARAMS::MASTER_COUNT),
        .SLAVE_COUNT(PARAMS::SLAVE_COUNT),
        .WAIT_WRITE_S0(PARAMS::WAIT_WRITE_S0),
        .WAIT_READ_S0(PARAMS::WAIT_READ_S0),
        .WAIT_WRITE_S1(PARAMS::WAIT_WRITE_S1),
        .WAIT_READ_S1(PARAMS::WAIT_READ_S1),
        .WAIT_WRITE_S2(PARAMS::WAIT_WRITE_S2),
        .WAIT_READ_S2(PARAMS::WAIT_READ_S2),
        .NUM_TIMERS(PARAMS::NUM_TIMERS)
    ) apb_sys (
        .ext_if(ext_if)
    );

    initial
        $fsdbDumpvars();

endmodule : APB_TOP