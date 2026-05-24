`timescale 1ns/1ps

module tb_digital_lock;

// 測試台：驗證 digital_lock 模組行為
// 測試內容：
// - 多組錯誤輸入以測試錯誤計數與鎖定
// - 正確輸入以測試解除功能
// - 重置行為測試

// ----- 信號宣告 -----
reg clk;            // 時脈 (10 ns 週期)
reg rst;            // 同步重置（高電位有效）
reg [3:0] key_in;   // 單鍵輸入
reg key_valid;      // 按鍵有效訊號

wire [3:0] seg_digit;
wire led_unlock;
wire led_error;
wire led_locked;
wire [1:0] error_count;

// ----- 被測模組 (DUT) 實體化 -----
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

// ----- 時脈產生：10ns 週期 -----
initial clk = 0;
always #5 clk = ~clk; 

// ----- Task：輸入四位密碼（依序按下 4 次） -----
task enter_password;
    input [3:0] d0,d1,d2,d3;
    begin
        press_key(d0);
        press_key(d1);
        press_key(d2);
        press_key(d3);
    end
endtask

// ----- Task：模擬按下一個按鍵 -----
task press_key;
    input [3:0] digit;
    begin
        @(posedge clk);
        key_in    = digit;
        key_valid = 1;
        @(posedge clk);
        key_valid = 0;
        #20; // 等待一些時間讓狀態轉移完成
    end
endtask

// ----- 測試流程 -----
initial begin
    // 啟動波形紀錄，方便後續檢視
    $dumpfile("wave.vcd"); 
    $dumpvars(0, tb_digital_lock); 

    // 初始值
    rst = 1; key_in = 0; key_valid = 0;
    #20; rst = 0;

    // 測試：連續三次錯誤輸入，檢查是否會鎖定
    $display("=== Error Input 1 ===");
    enter_password(9,9,9,9);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Error Input 2 ===");
    enter_password(0,0,0,0);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Error Input 3 ===");
    enter_password(1,1,1,1);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    // 重置系統以測試重置後行為
    #50;
    $display(">>> System Reset <<<");
    rst = 1; #10; rst = 0;

    // 測試正確與錯誤交替輸入
    $display("=== Error Input 4 ===");
    enter_password(2,2,2,2);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Correct Input 5 ===");
    enter_password(1,2,3,4);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Error Input 6 ===");
    enter_password(3,3,3,3);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Error Input 7 ===");
    enter_password(4,4,4,4);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Correct Input 8 ===");
    enter_password(1,2,3,4);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Error Input 9 ===");
    enter_password(7,7,7,7);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    $display("=== Correct Input 10 ===");
    enter_password(1,2,3,4);
    #20; $display("time=%t unlock=%d, error=%d, locked=%d, count=%d", $time, led_unlock, led_error, led_locked, error_count);

    #50;
    $finish; // 結束模擬
end

endmodule