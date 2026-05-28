`timescale 1ns/1ps

module tb_digital_lock;

// --- 信�� ---
reg clk;
reg rst;
reg [3:0] key_in;
reg key_valid;

wire [3:0] seg_digit;
wire led_unlock;
wire led_error;
wire led_locked;
wire [1:0] error_count;

// --- 待測(DUT) 實�---
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

// --- ��� (100MHz，週� 10ns) ---
initial clk = 0;
always #5 clk = ~clk;

// --- 模擬�鍵輸入�任(Task) ---
// 模擬��鍵後�key_valid ��一��週���
task press_key;
    input [3:0] digit;
    begin
        @(posedge clk);
        key_in = digit;
        key_valid = 1'b1;
        @(posedge clk);
        key_valid = 1'b0;
        #20; // 模擬�鍵���(Debounce) ���    
		  end
endtask

// --- 輸入��密碼�任(Task) ---
task enter_password;
    input [3:0] d0, d1, d2, d3;
    begin
        press_key(d0);
        press_key(d1);
        press_key(d2);
        press_key(d3);
    end
endtask

// --- 測試流� ---
initial begin
    // ��波形檔�紀    $dumpfile("wave.vcd");
    $dumpvars(0, tb_digital_lock);

    // 系統����步��    rst = 1; key_in = 0; key_valid = 0;
    #25; rst = 0;
    #20;

    // --- 測試�� 1: 止�密碼測試 (1->2->3->4) ---
    $display("=== Scenario 1: Correct Password (1-2-3-4) ===");
    enter_password(4'd1, 4'd2, 4'd3, 4'd4);
    #20;
    $display("Time=%t | led_unlock=%b, led_error=%b, led_locked=%b, seg_digit=%d", $time, led_unlock, led_error, led_locked, seg_digit);
    
    if (led_unlock) $display(">>> SUCCESS: System Unlocked");
    else $display(">>> FAILURE: System failed to unlock");

    // --- 測試�� 5: 中途�置測�(輸入��� rst) ---
    $display("\n>>> Resetting system...");
    rst = 1; #20; rst = 0; #20;
    $display("=== Scenario 5: Mid-input Reset ===");
    press_key(4'd1);
    press_key(4'd2);
    $display("Before reset: seg_digit=%d", seg_digit);
    rst = 1; #20; rst = 0; #20;
    $display("After reset:  seg_digit=%d", seg_digit);

    if (seg_digit == 0) $display(">>> SUCCESS: seg_digit reset to 0");
    else $display(">>> FAILURE: seg_digit not reset");

    // --- 測試�� 2: �次�誤測試 (1->2->3->5，�後�位錯� ---
    $display("\n=== Scenario 2: Single Error (1-2-3-5) ===");
    enter_password(4'd1, 4'd2, 4'd3, 4'd5);
    #5; // 稍微等�以�led_error ����    $display("Time=%t | led_unlock=%b, led_error=%b, led_locked=%b, error_count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (error_count == 1) $display(">>> SUCCESS: error_count incremented to 1");
    else $display(">>> FAILURE: error_count is %d", error_count);
/*
    // --- 測試�� 3: 三次�誤��測試 ---
    $display("\n=== Scenario 3: Three Errors Lockout ===");
    // ��已� 1 次錯�(�測�2 ��)
    // ���2 次錯誤輸    $display("Entering 2nd wrong password...");
    enter_password(4'd0, 4'd0, 4'd0, 4'd0);
    #20;
    // ���3 次錯誤輸    $display("Entering 3rd wrong password...");
    enter_password(4'd9, 4'd9, 4'd9, 4'd9);
    #20;
    $display("Time=%t | led_unlock=%b, led_error=%b, led_locked=%b, error_count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (led_locked) $display(">>> SUCCESS: System Locked");
    else $display(">>> FAILURE: System not locked");*/

    /*
    // --- 測試�� 4: ��後�置測�---
    $display("\n=== Scenario 4: Reset after Locked ===");
    $display("Trying to enter key while locked (expected ignore)...");
    press_key(4'd1);
    if (seg_digit == 0) $display("Key ignored as expected");
    
    $display("resetting...");
    rst = 1; #20; rst = 0; #20;
    $display("After reset: led_locked=%b, error_count=%d, seg_digit=%d", led_locked, error_count, seg_digit);
    
    $display("After reset, entering correct password...");
    enter_password(4'd1, 4'd2, 4'd3, 4'd4);
    #20;
    $display("Time=%t | led_unlock=%b, led_error=%b, led_locked=%b, error_count=%d", $time, led_unlock, led_error, led_locked, error_count);
    if (led_unlock) $display(">>> SUCCESS: System Unlocked after reset");
    else $display(">>> FAILURE: System failed to unlock after reset");
    */

    
    /*new*/
    //--- 測試情境 6: 輸入超時 ---
    $monitor("Time=%t | seg_digit=%d, led_locked=%b, error_count=%d", $time, seg_digit, led_locked, error_count);
    $display("\n=== Scenario 6: Timeout ===");
	 rst = 1; #20; rst = 0; #20;
    $display("Trying to enter key while locked (expected ignore)...");
    enter_password(4'd1, 4'd2, 4'd3, 4'd5);
    press_key(4'd1);
    if (seg_digit == 0) $display("Key ignored as expected");
    #205;

    #100;
    $finish; // 結�模擬
end

endmodule
