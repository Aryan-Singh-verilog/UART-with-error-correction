`timescale 1ns/1ps

module DuplexTest;

// Testbench signals
reg        reset_n_tb;
reg        send_tb;
reg        clock_tb;
reg [1:0]  parity_type_tb;
reg [1:0]  baud_rate_tb;
reg [7:0]  data_in_tb;

// Power management inputs
reg        power_enable_tb;
reg        tx_enable_tb;
reg        rx_enable_tb;
reg [1:0]  power_mode_tb;

// DUT outputs
wire       tx_active_flag_tb;
wire       tx_done_flag_tb;
wire       rx_active_flag_tb;
wire       rx_done_flag_tb;
wire [2:0] error_flag_tb;
wire [7:0] data_out_tb;
wire       power_good_tb;
wire [1:0] current_power_mode_tb;
wire       tx_clk_enable_tb;
wire       rx_clk_enable_tb;

// Internal probes for debugging
wire       serial_line;
wire       tx_baud_clk;
wire       rx_baud_clk;

// Test tracking
integer test_case;
integer pass_count;
integer fail_count;
reg [7:0] expected_data;
reg check_enabled;

// DUT instantiation
Duplex DUT(
    .reset_n(reset_n_tb),
    .send(send_tb),
    .clock(clock_tb),
    .parity_type(parity_type_tb),
    .baud_rate(baud_rate_tb),
    .data_in(data_in_tb),
    .power_enable(power_enable_tb),
    .tx_enable(tx_enable_tb),
    .rx_enable(rx_enable_tb),
    .power_mode(power_mode_tb),
    .tx_active_flag(tx_active_flag_tb),
    .tx_done_flag(tx_done_flag_tb),
    .rx_active_flag(rx_active_flag_tb),
    .rx_done_flag(rx_done_flag_tb),
    .error_flag(error_flag_tb),
    .data_out(data_out_tb),
    .power_good(power_good_tb),
    .current_power_mode(current_power_mode_tb),
    .tx_clk_enable(tx_clk_enable_tb),
    .rx_clk_enable(rx_clk_enable_tb)
);

// Waveform dump
initial begin
    $dumpfile("DuplexTest.vcd");
    $dumpvars(0, DuplexTest);
end

// Probe internal signals
assign serial_line = DUT.data_tx_w;
assign tx_baud_clk = DUT.Transmitter.Unit1.baud_clk;
assign rx_baud_clk = DUT.Receiver.Unit1.baud_clk;

// Clock generation - 50MHz (20ns period)
initial begin
    clock_tb = 1'b0;
    forever #10 clock_tb = ~clock_tb;
end

// Result checker - synchronized to rx_done_flag
always @(posedge rx_done_flag_tb) begin
    if (reset_n_tb && power_good_tb && check_enabled) begin
        @(posedge clock_tb);
        #50;
        
        if (data_out_tb == expected_data && error_flag_tb == 3'b000) begin
            $display("  PASS: Received 0x%02h (Expected 0x%02h) - No errors",
                data_out_tb, expected_data);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Received 0x%02h (Expected 0x%02h) - Error flags: %03b",
                data_out_tb, expected_data, error_flag_tb);
            if (error_flag_tb[0]) $display("      - Parity error detected");
            if (error_flag_tb[1]) $display("      - Start bit error detected");
            if (error_flag_tb[2]) $display("      - Stop bit error detected");
            fail_count = fail_count + 1;
        end
    end
end

// Debug monitors
always @(posedge rx_active_flag_tb) begin
    $display("  [DEBUG] RX became active at %0t ns", $time);
end

always @(posedge tx_active_flag_tb) begin
    $display("  [DEBUG] TX became active at %0t ns", $time);
end

always @(negedge serial_line) begin
    if (reset_n_tb && power_good_tb)
        $display("  [DEBUG] Start bit detected on serial line at %0t ns", $time);
end

// Main test sequence
initial begin
    // Initialize
    reset_n_tb = 1'b1;
    send_tb = 1'b0;
    data_in_tb = 8'h00;
    baud_rate_tb = 2'b10;
    parity_type_tb = 2'b00;
    test_case = 0;
    pass_count = 0;
    fail_count = 0;
    expected_data = 8'h00;
    check_enabled = 1'b0;
    
    // Power management - start enabled
    power_enable_tb = 1'b1;
    tx_enable_tb = 1'b1;
    rx_enable_tb = 1'b1;
    power_mode_tb = 2'b00;
    
    // Apply reset
    $display("[%0t] Applying reset...", $time);
    reset_n_tb = 1'b0;
    #1000;
    reset_n_tb = 1'b1;
    #2000;
    $display("[%0t] Reset complete", $time);
    
    // Diagnostics
    #1000;
    $display("\nPost-reset diagnostics:");
    $display("  power_good = %b", power_good_tb);
    $display("  tx_clk_enable = %b", tx_clk_enable_tb);
    $display("  rx_clk_enable = %b", rx_clk_enable_tb);
    $display("  current_power_mode = %b", current_power_mode_tb);
    $display("  serial_line = %b", serial_line);
    $display("  tx_baud_clk = %b", tx_baud_clk);
    $display("  rx_baud_clk = %b", rx_baud_clk);
    
    $display("\n========================================");
    $display("  UART Duplex Test Suite");
    $display("========================================\n");

    // ============================================================
    // Test Cases 1 through 6 (Unchanged)
    // ============================================================
    // Test Case 1
    test_case = 1;
    $display("[Test %0d] Basic No Parity - 0xAA", test_case);
    data_in_tb = 8'hAA;
    parity_type_tb = 2'b00;
    baud_rate_tb = 2'b10;
    expected_data = 8'hAA;
    check_enabled = 1'b1;
    $display("  Config: Data=0x%02h, Parity=None, Baud=9600 bps", data_in_tb);
    send_tb = 1'b1;
    #200000;
    send_tb = 1'b0;
    #1600000;
    wait(tx_active_flag_tb == 1'b0);
    #50000;
    wait(rx_active_flag_tb == 1'b0);
    #100000;

    // Test Case 2
    test_case = 2;
    $display("\n[Test %0d] Odd Parity - 0x55", test_case);
    data_in_tb = 8'h55;
    parity_type_tb = 2'b01;
    baud_rate_tb = 2'b11;
    expected_data = 8'h55;
    $display("  Config: Data=0x%02h, Parity=Odd, Baud=19200 bps", data_in_tb);
    send_tb = 1'b1;
    #100000;
    send_tb = 1'b0;
    #900000;
    wait(tx_active_flag_tb == 1'b0);
    #50000;
    wait(rx_active_flag_tb == 1'b0);
    #100000;

    // Test Case 3
    test_case = 3;
    $display("\n[Test %0d] Even Parity - 0xF0", test_case);
    data_in_tb = 8'hF0;
    parity_type_tb = 2'b10;
    baud_rate_tb = 2'b01;
    expected_data = 8'hF0;
    $display("  Config: Data=0x%02h, Parity=Even, Baud=4800 bps", data_in_tb);
    send_tb = 1'b1;
    #250000;
    send_tb = 1'b0;
    #3500000;
    wait(tx_active_flag_tb == 1'b0);
    #100000;
    wait(rx_active_flag_tb == 1'b0);
    #200000;

    // Test Case 4
    test_case = 4;
    $display("\n[Test %0d] All Zeros - 0x00", test_case);
    data_in_tb = 8'h00;
    parity_type_tb = 2'b01;
    baud_rate_tb = 2'b10;
    expected_data = 8'h00;
    $display("  Config: Data=0x%02h, Parity=Odd, Baud=9600 bps", data_in_tb);
    send_tb = 1'b1;
    #200000;
    send_tb = 1'b0;
    #1800000;
    wait(tx_active_flag_tb == 1'b0);
    #50000;
    wait(rx_active_flag_tb == 1'b0);
    #100000;

    // Test Case 5
    test_case = 5;
    $display("\n[Test %0d] All Ones - 0xFF", test_case);
    data_in_tb = 8'hFF;
    parity_type_tb = 2'b10;
    baud_rate_tb = 2'b10;
    expected_data = 8'hFF;
    $display("  Config: Data=0x%02h, Parity=Even, Baud=9600 bps", data_in_tb);
    send_tb = 1'b1;
    #200000;
    send_tb = 1'b0;
    #1800000;
    wait(tx_active_flag_tb == 1'b0);
    #50000;
    wait(rx_active_flag_tb == 1'b0);
    #100000;

    // Test Case 6
    test_case = 6;
    $display("\n[Test %0d] Power Management - TX Disabled", test_case);
    check_enabled = 1'b0;
    tx_enable_tb = 1'b0;
    data_in_tb = 8'hDE;
    parity_type_tb = 2'b00;
    baud_rate_tb = 2'b11;
    send_tb = 1'b1;
    #100000;
    send_tb = 1'b0;
    #2000000;
    if (tx_active_flag_tb == 1'b0) begin
        $display("  PASS: TX did not activate when disabled");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: TX activated despite being disabled");
        fail_count = fail_count + 1;
    end
    tx_enable_tb = 1'b1;
    #10000;

    // ============================================================
    // MODIFIED Test Case 7: Power Management - RX Disabled & Re-enabled
    // ============================================================
    test_case = 7;
    $display("\n[Test %0d] Power Management - RX Disabled", test_case);
    rx_enable_tb = 1'b0; // Turn RX OFF
    data_in_tb = 8'hAD;
    
    send_tb = 1'b1;
    #100000; // Hold for 100us
    send_tb = 1'b0;
    
    #2000000; // Wait long enough for the transmission to be missed
    
    if (rx_done_flag_tb == 1'b0) begin
        $display("  PASS: RX did not process data when disabled");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: RX processed data despite being disabled");
        fail_count = fail_count + 1;
    end
    
    // *** NEW BEHAVIOR STARTS HERE ***
    $display("  Re-enabling RX...");
    rx_enable_tb = 1'b1; // Turn RX back ON
    check_enabled = 1'b1; // Re-enable the result checker
    
    #1000000; // Wait for 1ms with RX on before proceeding to the next test
    
    // ============================================================
    // Test Case 8: Reset recovery (This will now happen AFTER RX is back on)
    // ============================================================
    test_case = 8;
    $display("\n[Test %0d] Reset Recovery", test_case);
    reset_n_tb = 1'b0; // <<-- RESET IS TRIGGERED HERE
    #1000;
    reset_n_tb = 1'b1;
    #2000;
    
    data_in_tb = 8'hBE;
    parity_type_tb = 2'b00;
    baud_rate_tb = 2'b10;
    expected_data = 8'hBE;
    
    $display("  Config: Data=0x%02h, Parity=None, Baud=9600 bps", data_in_tb);
    send_tb = 1'b1;
    #200000;
    send_tb = 1'b0;
    
    #1600000;
    wait(tx_active_flag_tb == 1'b0);
    #50000;
    wait(rx_active_flag_tb == 1'b0);
    #100000;

    // Test summary
    #5000;
    $display("\n========================================");
    $display("  Test Suite Complete");
    $display("========================================");
    $display("  Total Passed: %0d", pass_count);
    $display("  Total Failed: %0d", fail_count);
    if (pass_count + fail_count > 0) begin
        $display("  Success Rate: %.1f%%", (pass_count * 100.0) / (pass_count + fail_count));
    end
    $display("========================================\n");
    
    if (fail_count == 0 && pass_count > 0) begin
        $display("ALL TESTS PASSED!");
    end else if (pass_count == 0) begin
        $display("NO DATA RECEIVED - Check design connectivity and clocking");
    end else begin
        $display("SOME TESTS FAILED - Review waveform for details");
    end
    
    #10000;
    $finish;
end

// Timeout watchdog
initial begin
    #50000000;  // 50ms timeout
    $display("\nTIMEOUT: Test did not complete in expected time");
    $finish;
end

endmodule