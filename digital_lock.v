module digital_lock (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  key_in,
    input  wire        key_valid,
    output reg  [3:0]  seg_digit,
    output reg         led_unlock,
    output reg         led_error,
    output reg         led_locked,
    output reg  [1:0]  error_count
);

// ========== Configurable password digits ==========
parameter DIGIT0 = 4'd1;
parameter DIGIT1 = 4'd2;
parameter DIGIT2 = 4'd3;
parameter DIGIT3 = 4'd4;

// ========== State encoding ==========
localparam IDLE      = 3'd0;
localparam INPUT_1   = 3'd1; 
localparam INPUT_2   = 3'd2; 
localparam INPUT_3   = 3'd3; 
localparam CHECK     = 3'd4; 
localparam UNLOCKED  = 3'd5; 
localparam ERROR     = 3'd6; 
localparam LOCKED    = 3'd7; 

// State registers
reg [2:0] state, next_state;

// Storage for entered digits
reg [3:0] d0, d1, d2, d3;

// ====== 1) State register (clocked) ======
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

// ====== 2) Next-state combinational logic ======
always @(*) begin
    next_state = state; // Default: stay in current state
    case (state)
        IDLE: begin
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_1;
            else
                next_state = IDLE;
        end
        INPUT_1: begin
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_2;
            else
                next_state = INPUT_1;
        end
        INPUT_2: begin
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_3;
            else
                next_state = INPUT_2;
        end
        INPUT_3: begin
            if (key_valid && key_in <= 4'd9)
                next_state = CHECK;
            else
                next_state = INPUT_3;
        end
        CHECK: begin
            if ( (d0 == DIGIT0) && (d1 == DIGIT1) && (d2 == DIGIT2) && (d3 == DIGIT3) )
                next_state = UNLOCKED;
            else
                next_state = ERROR;
        end
        ERROR: begin
            // Transition to IDLE or LOCKED in next cycle
            if (error_count >= 2'd2) // This is the 3rd error (0, 1, 2)
                next_state = LOCKED;
            else
                next_state = IDLE;
        end
        UNLOCKED: begin
            // Wait for rst
            next_state = UNLOCKED;
        end
        LOCKED: begin
            // Wait for rst
            next_state = LOCKED;
        end
        default: next_state = IDLE;
    endcase
end

// ====== 3) Internal data & Error counter (clocked) ======
always @(posedge clk or posedge rst) begin
    if (rst) begin
        d0 <= 4'd0;
        d1 <= 4'd0;
        d2 <= 4'd0;
        d3 <= 4'd0;
        error_count <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                if (key_valid && key_in <= 4'd9)
                    d0 <= key_in;
            end
            INPUT_1: begin
                if (key_valid && key_in <= 4'd9)
                    d1 <= key_in;
            end
            INPUT_2: begin
                if (key_valid && key_in <= 4'd9)
                    d2 <= key_in;
            end
            INPUT_3: begin
                if (key_valid && key_in <= 4'd9)
                    d3 <= key_in;
            end
            CHECK: begin
                // If correct, reset error count. If wrong, ERROR state handles increment.
                if ( (d0 == DIGIT0) && (d1 == DIGIT1) && (d2 == DIGIT2) && (d3 == DIGIT3) )
                    error_count <= 2'd0;
            end
            ERROR: begin
                if (error_count < 2'd3)
                    error_count <= error_count + 2'd1;
            end
            default: ;
        endcase
    end
end

// ====== 4) Output logic (combinational or sequential) ======
// Using sequential for glitch-free outputs and following Verilog-2001 style
always @(posedge clk or posedge rst) begin
    if (rst) begin
        seg_digit    <= 4'd0;
        led_unlock   <= 1'b0;
        led_error    <= 1'b0;
        led_locked   <= 1'b0;
    end else begin
        // Default values
        led_error <= 1'b0;
        
        case (next_state) // Lookahead to next_state for faster output response if needed, 
                          // or use current state. The prompt says "一拍" for error.
                          // Let's use current state to be safe and match "一拍" exactly.
            default: ; 
        endcase

        // Using current state for standard Moore FSM outputs
        case (state)
            IDLE: begin
                seg_digit    <= 4'd0;
                led_unlock   <= 1'b0;
                led_locked   <= 1'b0;
            end
            INPUT_1: begin
                seg_digit <= 4'd1;
            end
            INPUT_2: begin
                seg_digit <= 4'd2;
            end
            INPUT_3: begin
                seg_digit <= 4'd3;
            end
            CHECK: begin
                seg_digit <= 4'd4;
            end
            UNLOCKED: begin
                led_unlock <= 1'b1;
            end
            ERROR: begin
                led_error <= 1'b1;
            end
            LOCKED: begin
                led_locked <= 1'b1;
            end
        endcase
    end
end

endmodule
