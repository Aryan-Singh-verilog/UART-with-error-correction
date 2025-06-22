//  AUTHOR: Enhanced by AI Assistant
//  FILE NAME: EnhancedDuplexTest.v
//  TYPE: Test fixture with adaptive error correction testing
//  PURPOSE: Comprehensive testbench for adaptive UART system

`timescale 1ns/1ps

module EnhancedDuplexTest;

// Testbench signals
reg         reset_n_tb;
reg         send_tb;
reg         clock_tb;
reg  [1:0]  manual_parity_type_tb;
reg  [1:0]  baud_rate_tb;
reg  [7:0]  data_in_tb;
reg         enable_adaptation_tb;
reg         force_retransmit_tb;

// DUT outputs
wire        tx_active_flag_tb;
wire        tx_done_flag_tb;
wire        rx_active_flag_tb;
wire        rx_done_flag_tb;
wire [7:0]  data_out_tb;
wire [2:0]  error_flag_tb;
wire [1:0]  current_parity_type_tb;
wire        retransmit_needed_tb;
wire [7:0]  error_statistics_tb;
wire        adaptation_active_tb;
wire        data_valid_tb;

// Test control variables
integer     test_case;
integer     error_injection_count;
reg [7:0]   test_data [0:15]; // Array of test data
integer     data_index;

// DUT instantiation
Duplex DUT(
    // Inputs
    .reset_n(reset_n_tb),
    .send(send_tb),
    .clock(clock_tb),
    .manual_parity_type(manual_parity_type_tb),
    .baud_rate(baud_rate_tb),
    .data_in(data_in_tb),
    .enable_adaptation(enable_adaptation_tb),
    .force_retransmit(force_retransmit_tb),
    
    // Outputs
    .tx_active_flag(tx_active_flag_tb),
    .tx_done_flag(tx_done_flag_tb),
    .rx_active_flag(rx_active_flag_tb),
    .rx_done_flag(rx_done_flag_tb),
    .data_out(data_out_tb),
    .error_flag(error_flag_tb),
    .current_parity_type(current_parity_type_tb),
    .retransmit_needed(retransmit_needed_tb),
    .error_statistics(error_statistics_tb),
    .adaptation_active(adaptation_active_tb),
    .data_valid(data_valid_tb)
);

// Wave form generation
initial begin
    $dumpfile("EnhancedDuplexTest.vcd");
    $dumpvars(0, EnhancedDuplexTest);
end

// Enhanced monitoring
initial begin
    $monitor($time, " | Test Case: %0d | Data: %h->%h | Parity: %b | Errors: %b | Valid: %b | Adapt: %b | Retrans: %b | Stats: %d",
             test_case, data_in_tb, data_out_tb, current_parity_type_tb, error_flag_tb, 
             data_valid_tb, adaptation_active_tb, retransmit_needed_tb, error_statistics_tb);
end

// Clock generation (50MHz)
initial begin
    clock_tb = 1'b0;
    forever #10 clock_tb = ~clock_tb;
end

// Initialize test data array
initial begin
    test_data[0]  = 8'hAA;  // 10101010
    test_data[1]  = 8'h55;  // 01010101
    test_data[2]  = 8'hFF;  // 11111111
    test_data[3]  = 8'h00;  // 00000000
    test_data[4]  = 8'h0F;  // 00001111
    test_data[5]  = 8'hF0;  // 11110000
    test_data[6]  = 8'h33;  // 00110011
    test_data[7]  = 8'hCC;  // 11001100
    test_data[8]  = 8'h5A;  // 01011010
    test_data[9]  = 8'hA5;  // 10100101
    test_data[10] = 8'h69;  // 01101001
    test_data[11] = 8'h96;  // 10010110
    test_data[12] = 8'h3C;  // 00111100
    test_data[13] = 8'hC3;  // 11000011
    test_data[14] = 8'h7E;  // 01111110
    test_data[15] = 8'h81;  // 10000001
end

// Main test sequence
initial begin
    // Initialize all signals
    reset_n_tb = 1'b0;
    send_tb = 1'b0;
    manual_parity_type_tb = 2'b10; // Start with even parity
    baud_rate_tb = 2'b10;          // 9600 baud
    data_in_tb = 8'h00;
    enable_adaptation_tb = 1'b0;
    force_retransmit_tb = 1'b0;
    test_case = 0;
    data_index = 0;
    error_injection_count = 0;
    
    $display("========== Enhanced UART Adaptive Error Correction Test ==========");
    
    // Reset sequence
    #100;
    reset_n_tb = 1'b1;
    #100;
    
    // Test Case 1: Basic transmission without adaptation
    test_case = 1;
    $display("Test Case 1: Basic transmission (no adaptation)");
    enable_adaptation_tb = 1'b0;
    
    repeat(4) begin
        data_in_tb = test_data[data_index];
        send_tb = 1'b1;
        #20;
        send_tb = 1'b0;
        
        // Wait for transmission to complete
        wait(tx_done_flag_tb);
        wait(rx_done_flag_tb);
        #1000;
        
        data_index = data_index + 1;
    end
    
    #10000;
    
    // Test Case 2: Enable adaptation and observe behavior
    test_case = 2;
    $display("Test Case 2: Enable adaptive error correction");
    enable_adaptation_tb = 1'b1;
    #1000;
    
    // Send multiple transmissions to build error history
    repeat(8) begin
        data_in_tb = test_data[data_index % 16];
        send_tb = 1'b1;
        #20;
        send_tb = 1'b0;
        
        wait(tx_done_flag_tb);
        wait(rx_done_flag_tb);
        #2000; // Longer wait to allow adaptation processing
        
        if (current_parity_type_tb != manual_parity_type_tb) begin
            $display("Adaptation detected! Parity changed from %b to %b", 
                    manual_parity_type_tb, current_parity_type_tb);
        end
        
        data_index = data_index + 1;
    end
    
    #10000;
    
    // Test Case 3: Force retransmission
    test_case = 3;
    $display("Test Case 3: Force retransmission test");
    
    data_in_tb = 8'hAB;
    send_tb = 1'b1;
    #20;
    send_tb = 1'b0;
    
    wait(tx_done_flag_tb);
    #1000;
    
    // Force a retransmission
    force_retransmit_tb = 1'b1;
    #100;
    force_retransmit_tb = 1'b0;
    
    wait(tx_done_flag_tb);
    wait(rx_done_flag_tb);
    #5000;
    
    // Test Case 4: Different baud rates with adaptation
    test_case = 4;
    $display("Test Case 4: Different baud rates with adaptation");
    
    // Test with 19200 baud
    baud_rate_tb = 2'b11;
    
    repeat(3) begin
        data_in_tb = test_data[data_index % 16];
        send_tb = 1'b1;
        #20;
        send_tb = 1'b0;
        
        wait(tx_done_flag_tb);
        wait(rx_done_flag_tb);
        #1000;
        
        data_index = data_index + 1;
    end
    
    #10000;
    
    // Test Case 5: Stress test with rapid transmissions
    test_case = 5;
    $display("Test Case 5: Stress test with rapid transmissions");
    
    repeat(6) begin
        data_in_tb = test_data[data_index % 16];
        send_tb = 1'b1;
        #20;
        send_tb = 1'b0;
        
        wait(tx_done_flag_tb);
        wait(rx_done_flag_tb);
        #500; // Shorter wait for stress test
        
        data_index = data_index + 1;
    end
    
    #20000;
    
    // Test Case 6: Disable adaptation mid-operation
    test_case = 6;
    $display("Test Case 6: Disable adaptation during operation");
    
    enable_adaptation_tb = 1'b0;
    manual_parity_type_tb = 2'b01; // Switch to odd parity manually
    
    repeat(3) begin
        data_in_tb = test_data[data_index % 16];
        send_tb = 1'b1;
        #20;
        send_tb = 1'b0;
        
        wait(tx_done_flag_tb);
        wait(rx_done_flag_tb);
        #1000;
        
        data_index = data_index + 1;
    end
    
    #10000;
    
    $display("========== Test Completed ==========");
    $display("Final Statistics:");
    $display("- Final Parity Type: %b", current_parity_type_tb);
    $display("- Final Error Statistics: %d", error_statistics_tb);
    $display("- Adaptation Active: %b", adaptation_active_tb);
    
    #5000;
    $finish;
end

// Error statistics monitoring
always @(posedge clock_tb) begin
    if (rx_done_flag_tb && |error_flag_tb) begin
        error_injection_count = error_injection_count + 1;
        $display("Error detected at time %t: Type=%b, Count=%d", 
                $time, error_flag_tb, error_injection_count);
    end
end

// Adaptation monitoring
always @(posedge clock_tb) begin
    if (adaptation_active_tb && retransmit_needed_tb) begin
        $display("Retransmission recommended at time %t", $time);
    end
end

endmodule