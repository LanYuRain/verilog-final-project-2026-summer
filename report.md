# 報告

## 程式碼實作邏輯說明

本設計採用 **三段式有限狀態機 (FSM)** 架構，確保邏輯清晰且易於維護。

以下程式功能為時脈上升緣或重置訊號時，更新狀態機的當前狀態的方式。若 `rst` 為高電位，則切換到 `IDLE`；否則切換到下個狀態。
```verilog
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end
```

以下程式專注於實現狀態切換的邏輯。系統根據當前狀態與輸入信號決定下一個狀態，包含密碼輸入流程、正確與否的判斷，以及鎖定機制的轉換。
```verilog
always @(*) begin
    next_state = state;
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
            if (error_count >= 2'd2)
                next_state = LOCKED;
            else
                next_state = IDLE;
        end
        UNLOCKED: begin
            next_state = UNLOCKED;
        end
        LOCKED: begin
            next_state = LOCKED;
        end
        default: next_state = IDLE;
    endcase
end
```

以下程式負責處理內部的資料存取與錯誤計數。在不同狀態下接收輸入位數並儲存，或在密碼錯誤時增加計數器。
```verilog
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
```

以下程式為輸出控制邏輯。根據當前狀態驅動 7 段顯示器（顯示位數）以及各個 LED 指示燈（解鎖、錯誤、鎖定）。
```verilog
always @(posedge clk or posedge rst) begin
    if (rst) begin
        seg_digit    <= 4'd0;
        led_unlock   <= 1'b0;
        led_error    <= 1'b0;
        led_locked   <= 1'b0;
    end else begin
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
                seg_digit = 4'd0;
            end
        endcase
    end
end
```

## 模擬結果分析

根據 `vvp` 執行測試腳本 `tb_digital_lock.v` 的結果，各項測試情境均符合預期：

| 測試情境 | 預期行為 | 模擬結果 | 結論 |
| :--- | :--- | :--- | :--- |
| **正確密碼測試** | 輸入 1-2-3-4 後 `led_unlock` 拉高 | `unlock=1`, `digit=4` | **符合** |
| **中途重置測試** | 輸入一半按下 `rst`，`seg_digit` 歸零 | `After reset: digit=0` | **符合** |
| **單次錯誤測試** | 輸入 1-2-3-5 後 `led_error` 拉高一拍，`count` 變 1 | `error=1`, `count=1` | **符合** |
| **三次錯誤鎖定** | 連續三次錯誤後 `led_locked` 拉高 | `locked=1`, `count=3` | **符合** |
| **鎖定後重置** | 鎖定狀態下 `rst` 可恢復正常輸入 | `SUCCESS: System Unlocked after reset` | **符合** |

## 編譯與模擬輸出結果

以下為執行 `compile.cmd` 的完整終端機輸出：

```text
VCD info: dumpfile wave.vcd opened for output.
=== Scenario 1: Correct Password (1-2-3-4) ===
Time=              185000 | led_unlock=1, led_error=0, led_locked=0, seg_digit= 4
>>> SUCCESS: System Unlocked

>>> Resetting system...
=== Scenario 5: Mid-input Reset ===
Before reset: seg_digit= 2
After reset:  seg_digit= 0
>>> SUCCESS: seg_digit reset to 0

=== Scenario 2: Single Error (1-2-3-5) ===
Time=              450000 | led_unlock=0, led_error=1, led_locked=0, error_count=1
>>> SUCCESS: error_count incremented to 1

=== Scenario 3: Three Errors Lockout ===
Entering 2nd wrong password...
Entering 3rd wrong password...
Time=              735000 | led_unlock=0, led_error=0, led_locked=1, error_count=3
>>> SUCCESS: System Locked

=== Scenario 4: Reset after Locked ===
Trying to enter key while locked (expected ignore)...
Key ignored as expected
resetting...
After reset: led_locked=0, error_count=0, seg_digit= 0
After reset, entering correct password...
Time=              945000 | led_unlock=1, led_error=0, led_locked=0, error_count=0
>>> SUCCESS: System Unlocked after reset
tb_digital_lock.v:133: $finish called at 1045000 (1ps)
```

