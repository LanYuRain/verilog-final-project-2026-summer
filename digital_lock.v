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
// Module: digital_lock
// Description:
// - Receives four key presses (key_in, key_valid) and stores them as d0..d3
// - Compares the entered digits to the configured password (DIGIT0..DIGIT3)
// - On correct password, enters UNLOCKED state (led_unlock) for a duration, then returns to IDLE
// - On incorrect password, increments error_count; after three errors the system goes to LOCKED (led_locked)

// Interface:
// - clk        : clock input
// - rst        : synchronous reset (active high)
// - key_in     : 4-bit key value input
// - key_valid  : key valid pulse (one clock cycle per key press)
// - seg_digit  : indicates which digit is being entered (1..4) or status
// - led_unlock : unlock indicator
// - led_error  : error indicator
// - led_locked : locked indicator
// - error_count: number of errors (0..3)

// ========== Configurable password digits ==========
parameter DIGIT0 = 4'd1;
parameter DIGIT1 = 4'd2;
parameter DIGIT2 = 4'd3;
parameter DIGIT3 = 4'd4;

// ========== State encoding ==========
localparam IDLE      = 3'd0;
localparam INPUT_1   = 3'd1; // first digit entered
localparam INPUT_2   = 3'd2; // second digit entered
localparam INPUT_3   = 3'd3; // third digit entered
localparam CHECK     = 3'd4; // compare all four digits
localparam UNLOCKED  = 3'd5; // unlocked state
localparam ERROR     = 3'd6; // error state, increment error_count
localparam LOCKED    = 3'd7; // system locked

// State registers
reg [2:0] state, next_state;

// Storage for entered digits
reg [3:0] d0, d1, d2, d3;

// Unlock-state timer (clock cycles)
reg [7:0] unlock_timer;

// ====== 1) State register (clocked) ======
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

// ====== 2) Next-state combinational logic ======
always @(*) begin
    case (state)
        IDLE:     next_state = key_valid ? INPUT_1 : IDLE;
        INPUT_1:  next_state = key_valid ? INPUT_2 : INPUT_1;
        INPUT_2:  next_state = key_valid ? INPUT_3 : INPUT_2;
        INPUT_3:  next_state = key_valid ? CHECK   : INPUT_3;
        CHECK: begin
            if ( (d0==DIGIT0)&&(d1==DIGIT1)&&(d2==DIGIT2)&&(d3==DIGIT3) )
                next_state = UNLOCKED; // correct password
            else
                next_state = ERROR;    // incorrect password
        end
        ERROR: begin
            // If error_count == 2 (this will be the 3rd error), go to LOCKED
            if (error_count == 2)
                next_state = LOCKED;
            else
                next_state = IDLE;
        end
        UNLOCKED: begin
            // Stay in UNLOCKED for a fixed number of clock cycles
            if (unlock_timer >= 20)
                next_state = IDLE;
            else
                next_state = UNLOCKED;
        end
        LOCKED:   next_state = LOCKED; // permanently locked
        default:  next_state = IDLE;
    endcase
end

// ====== 3) Outputs and internal updates (clocked) ======
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset outputs and internal storage
        seg_digit    <= 0;
        led_unlock   <= 0;
        led_error    <= 0;
        led_locked   <= 0;
        error_count  <= 0;
        d0<=0; d1<=0; d2<=0; d3<=0;
        unlock_timer <= 0;
    end else begin
        // Default values for this clock cycle
        led_error <= 0;

        case (state)
            IDLE: begin
                led_unlock   <= 0;
                led_locked   <= 0;
                seg_digit    <= 0;
                unlock_timer <= 0; // clear unlock timer when returning to IDLE
                if (key_valid) d0 <= key_in; // capture first digit on key press
            end

            INPUT_1: begin
                seg_digit <= 1; // indicate entering digit 1
                if (key_valid) d1 <= key_in;
            end

            INPUT_2: begin
                seg_digit <= 2; // indicate entering digit 2
                if (key_valid) d2 <= key_in;
            end

            INPUT_3: begin
                seg_digit <= 3; // indicate entering digit 3
                if (key_valid) d3 <= key_in;
            end

            CHECK: begin
                seg_digit <= 4; // indicate checking password
            end

            UNLOCKED: begin
                led_unlock   <= 1;                // show unlock
                unlock_timer <= unlock_timer + 1; // increment unlock timer
            end

            ERROR: begin
                led_error <= 1;                  // show error
                error_count <= error_count + 1;  // increment error count
            end

            LOCKED: begin
                led_locked <= 1; // show locked
            end
        endcase
    end
end

endmodule
