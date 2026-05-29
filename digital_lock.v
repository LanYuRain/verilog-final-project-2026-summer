module digital_lock (
    input  wire        clk,          // 系統時脈
    input  wire        rst,          // 非同步重置（高電位有效）
    input  wire [3:0]  key_in,       // 使用者輸入數字 (0-9)
    input  wire        key_valid,    // 輸入有效脈衝
    /*new*/
    input  wire        key_enter,
    input  wire        key_cancel,   // 高電位取消目前輸入
    output reg  [3:0]  seg_digit,    // 當前已輸入位數 (0-4)
    output reg         led_unlock,   // 解鎖成功指示燈
    output reg         led_error,    // 輸入錯誤指示燈（維持一拍）
    output reg         led_locked,   // 系統鎖定指示燈（連續三次錯誤）
    output reg  [1:0]  error_count   // 當前累計錯誤次數
);

// ========== 可配置密碼位數 (預設密碼 1-2-3-4) ==========
parameter DIGIT0 = 4'd1;
parameter DIGIT1 = 4'd2;
parameter DIGIT2 = 4'd3;
parameter DIGIT3 = 4'd4;


//超過此時間回到IDLE(為方便波形測試設成較小的數)
parameter TIMEOUT_MAX = 5'd20;

// ========== 有限狀態機 (FSM) 狀態編碼 ==========
localparam IDLE      = 3'd0; // 等待第 1 位
localparam INPUT_1   = 3'd1; // 已收第 1 位，等待第 2 位
localparam INPUT_2   = 3'd2; // 已收第 2 位，等待第 3 位
localparam INPUT_3   = 3'd3; // 已收第 3 位，等待第 4 位
localparam CHECK     = 3'd4; // 密碼比對狀態
localparam UNLOCKED  = 3'd5; // 解鎖成功狀態
localparam ERROR     = 3'd6; // 密碼錯誤狀態
localparam LOCKED    = 3'd7; // 系統鎖定狀態

// 狀態暫存器
reg [2:0] state, next_state;

// 儲存輸入數字的暫存器
reg [3:0] d0, d1, d2, d3;


//計時器
reg [4:0] timeout_counter;

// ====== 1) 狀態暫存器 (序向邏輯) ======
// 處理狀態轉換與系統重置
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

// ====== 2) 次態邏輯 (組合邏輯) ======
// 根據當前狀態與輸入條件判斷下一個狀態
always @(*) begin
    next_state = state; // 預設保持當前狀態
    case (state)
        IDLE: begin
            // 收到有效數字且在 0-9 範圍內，進入下一個輸入階段
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_1;
            else
                next_state = IDLE;
        end
        INPUT_1: begin
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_2;
            /*new*/
            else if(key_cancel)
                next_state = IDLE;
            else if(timeout_counter >= TIMEOUT_MAX)
                next_state = IDLE;
            else
                next_state = INPUT_1;
        end
        INPUT_2: begin
            if (key_valid && key_in <= 4'd9)
                next_state = INPUT_3;
            /*new*/
            else if(key_cancel)
                next_state = IDLE;
            else if(timeout_counter >= TIMEOUT_MAX)
                next_state = IDLE;
            else
                next_state = INPUT_2;
        end
        INPUT_3: begin
            if (key_valid && key_in <= 4'd9)
                next_state = CHECK;
            /*new*/
            else if(key_cancel)
                next_state = IDLE;
            else if(timeout_counter >= TIMEOUT_MAX)
                next_state = IDLE;
            else
                next_state = INPUT_3;
        end
        
        CHECK: begin
            // 比對四位數暫存器與預設密碼是否全等
            if(key_enter) begin
                if ( (d0 == DIGIT0) && (d1 == DIGIT1) && (d2 == DIGIT2) && (d3 == DIGIT3) )
                    next_state = UNLOCKED;
                else
                    next_state = ERROR;
            end
            else if(key_cancel)
                next_state = IDLE;
            else if(timeout_counter >= TIMEOUT_MAX)
                next_state = IDLE;
            else 
                next_state = CHECK;
        end
        ERROR: begin
            // 判斷錯誤次數是否已達上限 (第 3 次錯誤後鎖定)
            if (error_count >= 2'd2) 
                next_state = LOCKED;
            else
                next_state = IDLE;
        end
        UNLOCKED: begin
            // 解鎖後保持在該狀態，直到按下重置
            next_state = UNLOCKED;
        end
        LOCKED: begin
            // 鎖定後拒絕任何輸入，直到按下重置
            next_state = LOCKED;
            seg_digit = 4'd0;
        end
        default: next_state = IDLE;
    endcase
end

// ====== 3) 內部資料儲存與錯誤計數 (序向邏輯) ======
// 負責存儲输入的密碼與維護錯誤計數器
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
                // 如果密碼正確，清除錯誤計數。若錯誤，則由 ERROR 狀態處理遞增。
                if(key_enter)begin
                    if ( (d0 == DIGIT0) && (d1 == DIGIT1) && (d2 == DIGIT2) && (d3 == DIGIT3) )
                        error_count <= 2'd0;
                end
                
            end
            ERROR: begin
                // 進入錯誤狀態時遞增計數器
                if (error_count < 2'd3)
                    error_count <= error_count + 2'd1;
            end
            default: ;
        endcase
    end
end

// ====== 4) 輸出邏輯 (序向邏輯) ======
// 採用 Moore FSM 風格，根據當前狀態驅動各項輸出指示
always @(posedge clk or posedge rst) begin
    if (rst) begin
        seg_digit    <= 4'd0;
        led_unlock   <= 1'b0;
        led_error    <= 1'b0;
        led_locked   <= 1'b0;
    end else begin
        // 預設將錯誤燈熄滅，確保它只亮起一拍
        led_error <= 1'b0;
        
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
                seg_digit <= 4'd0;
            end
        endcase
    end
end


/*計數*/
always @(posedge clk or posedge rst) begin
    if(rst) begin
        timeout_counter <= 5'd0;
    end
    else begin
        if(state == IDLE)
            timeout_counter <= 5'd0;
        else if(key_valid)
            timeout_counter <= 5'd0;
        else
            timeout_counter <= timeout_counter + 5'd1;
    end
end

endmodule
