`timescale 1ns/1ps

module tb_digital_lock;

// 信號宣告
reg clk;
reg rst;
reg [3:0] key_in;
reg key_valid;

wire [3:0] seg_digit;
wire led_unlock;
wire led_error;
wire led_locked;
wire [1:0] error_count;

// DUT 實體化
digital_lock uut (
    .clk(clk),
    .rst(rst),
    .key_in(key_in),
    .key_valid(key_valid),
    .seg_digit(seg_digit),
    .led_unlock(led_unlock),
    .led_error(led_error),
    .led_locked(led_locked),
    .error_count(error_count)
);

// 時脈產生 (100MHz)
initial clk = 0;
always #5 clk = ~clk;

// 模擬按鍵輸入的 task
task press_key;
    input [3:0] digit;
    begin
        @(posedge clk);
        key_in = digit;
        key_valid = 1'b1;
        @(posedge clk);
        key_valid = 1'b0;
        #20; // 模擬去彈跳間隔
    end
endtask

// 輸入四位密碼的 task
task enter_password;
    input [3:0] d0, d1, d2, d3;
    begin
        press_key(d0);
        press_key(d1);
        press_key(d2);
        press_key(d3);
    end
endtask

// 測試流程
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_digital_lock);

    // 初始狀態
    rst = 1; key_in = 0; key_valid = 0;
    #25; rst = 0;
    #20;

    // --- 測試 1: 正確密碼測試 (1->2->3->4) ---
    $display("=== Correct Password (1-2-3-4) ===");
    enter_password(4'd1, 4'd2, 4'd3, 4'd4);
    #20;
    $display("Time=%t | unlock=%b, error=%b, locked=%b, digit=%d", $time, led_unlock, led_error, led_locked, seg_digit);
    
    if (led_unlock) $display(">>> SUCCESS: System Unlocked");
    else $display(">>> ERROR: System failed to unlock");

    // --- 測試 5: 中途重置測試 (輸入一半時按 rst) ---
    $display("\n>>> Resetting system...");
    rst = 1; #20; rst = 0; #20;
    $display("=== Scenario 5: Mid-input Reset ===");
    press_key(4'd1);
    press_key(4'd2);
    $display("Before reset: seg_digit=%d", seg_digit);
    rst = 1; #20; rst = 0; #20;
    $display("After reset:  seg_digit=%d", seg_digit);

    if (seg_digit == 0) $display(">>> SUCCESS: seg_digit reset to 0");
    else $display(">>> ERROR: seg_digit not reset");

    // --- 測試 2: 單次錯誤測試 (1->2->3->5) ---
    $display("\n=== Scenario 2: Single Error (1-2-3-5) ===");
    enter_password(4'd1, 4'd2, 4'd3, 4'd5);
    #5;
    $display("Time=%t | unlock=%b, error=%b, locked=%b, count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (error_count == 1) $display(">>> SUCCESS: error_count incremented to 1");
    else $display(">>> ERROR: error_count is %d", error_count);

    // --- 測試 3: 三次錯誤鎖定測試 ---
    $display("\n=== Scenario 3: Three Errors Lockout ===");
    // 目前已經有 1 次錯誤 (1-2-3-5)
    // 第 2 次錯誤
    $display("Entering 2nd wrong password...");
    enter_password(4'd0, 4'd0, 4'd0, 4'd0);
    #20;
    // 第 3 次錯誤
    $display("Entering 3rd wrong password...");
    enter_password(4'd9, 4'd9, 4'd9, 4'd9);
    #20;
    $display("Time=%t | unlock=%b, error=%b, locked=%b, count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (led_locked) $display(">>> SUCCESS: System Locked");
    else $display(">>> ERROR: System not locked");

    // --- 測試 4: 鎖定後重置測試 ---
    $display("\n=== Scenario 4: Reset after Locked ===");
    $display("Trying to enter key while locked...");
    press_key(4'd1);
    if (seg_digit == 0) $display("Key ignored as expected");
    
    $display("Resetting...");
    rst = 1; #20; rst = 0; #20;
    $display("After reset: locked=%b, count=%d, digit=%d", led_locked, error_count, seg_digit);
    
    $display("Entering correct password after reset...");
    enter_password(4'd1, 4'd2, 4'd3, 4'd4);
    #20;
    $display("Time=%t | unlock=%b, error=%b, locked=%b, count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (led_unlock) $display(">>> SUCCESS: System Unlocked after reset");
    else $display(">>> ERROR: System failed to unlock after reset");

    #100;
    $finish;
end

endmodule
