// ==============================================================================
// APB Timer Module
// ==============================================================================
module APB_Timer #(
    // Parameters declared before ports so they can be used for sizing
    parameter DATA_WIDTH = 32,                                    // Data bus width
    parameter ADDR_WIDTH = 32,                                    // Address bus width
    parameter WAIT_WRITE = 0,                                     // Number of wait cycles following a write command
    parameter WAIT_READ  = 0,                                     // Number of wait cycles following a read command
    parameter num_timers = 2                                      // Default number of timers
) (
    input  logic i_prstn,
    input  logic i_pclk,
    input  logic [ADDR_WIDTH-1:0] i_paddr,
    input  logic i_pwrite,
    input  logic i_psel,
    input  logic i_penable,
    input  logic [DATA_WIDTH-1:0] i_pwdata,
    output logic [DATA_WIDTH-1:0] o_prdata,
    output logic o_pready,
    output logic o_pslverr
);

localparam WAIT_MAX  = 3;                                     // Maximum number of wait cycles is 2^WAIT_MAX-1.
localparam WORD_LEN = $clog2(DATA_WIDTH>>3);                  // Byte offset for word-aligned addresses
localparam TIMER_IDX_W = (num_timers <= 1) ? 1 : $clog2(num_timers);

// Internal Signals
logic [WAIT_MAX-1:0] count_pready;                            // Wait state counter 
logic [DATA_WIDTH-1:0] t_reg [num_timers];                    // Timer Registers

// Address decoding to determine which timer is being accessed
wire [TIMER_IDX_W-1:0] timer_idx = i_paddr[WORD_LEN +: TIMER_IDX_W];

// ==============================================================================
// Timer Decrement & APB Write Logic
// ==============================================================================
always_ff @(posedge i_pclk or negedge i_prstn) begin
    if (!i_prstn) begin
        for (int i = 0; i < num_timers; i++) begin
            t_reg[i] <= '0;
        end
    end 
    else begin
        // 1. Default Timer Behavior: Decrement if > 0
        for (int i = 0; i < num_timers; i++) begin
            if (t_reg[i] > 0) begin
                t_reg[i] <= t_reg[i] - 1;
            end
        end

        // 2. APB Write: Overrides the decrement if a new value is written
        if (i_psel && i_penable && i_pwrite && o_pready) begin
            if (timer_idx < num_timers) begin
                t_reg[timer_idx] <= i_pwdata;
            end
        end
    end
end

// ==============================================================================
// APB Read & Wait State Protocol Logic
// ==============================================================================
always_ff @(posedge i_pclk or negedge i_prstn) begin
    if (!i_prstn) begin
        count_pready <= '0;
        o_pready     <= 1'b0;
        o_prdata     <= '0;
    end
    // APB Setup Phase
    else if (i_psel && !i_penable) begin
        count_pready <= '0;
        if (i_pwrite && WAIT_WRITE == 0) begin         // Write command, no wait states
            o_pready <= 1'b1;
        end 
        else if (!i_pwrite && WAIT_READ == 0) begin    // Read command, no wait states
            o_pready <= 1'b1;
            o_prdata <= (timer_idx < num_timers) ? t_reg[timer_idx] : '0;
        end 
        else begin
            o_pready <= 1'b0;
        end
    end
    // APB Access Phase - Write with Wait States
    else if (i_pwrite && i_psel) begin
        if (count_pready == $bits(count_pready)'(WAIT_WRITE-1)) begin
            o_pready     <= 1'b1;
            count_pready <= count_pready + $bits(count_pready)'(1);	  
        end 
        else if (count_pready == $bits(count_pready)'(WAIT_WRITE)) begin
            o_pready <= 1'b0;
        end 
        else begin
            count_pready <= count_pready + $bits(count_pready)'(1);
        end
    end
    // APB Access Phase - Read with Wait States
    else if (!i_pwrite && i_psel) begin
        if (count_pready == $bits(count_pready)'(WAIT_READ-1)) begin                    
            o_pready     <= 1'b1;
            o_prdata     <= (timer_idx < num_timers) ? t_reg[timer_idx] : '0;
            count_pready <= count_pready + $bits(count_pready)'(1);
        end 
        else if (count_pready == $bits(count_pready)'(WAIT_READ)) begin
            o_pready <= 1'b0;
        end 
        else begin
            count_pready <= count_pready + $bits(count_pready)'(1);
        end
    end
end

// Error signal tied to zero for this implementation
assign o_pslverr = 1'b0;

endmodule