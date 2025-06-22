//  AUTHOR: Enhanced by AI Assistant based on Mohamed Maged Elkholy's work.
//  FILE NAME: AdaptiveErrorCorrection.v
//  TYPE: module.
//  KEYWORDS: Machine Learning, Adaptive, Error Correction, Dynamic Parity.
//  PURPOSE: An RTL modelling for adaptive error correction that dynamically
//  adjusts parity type and transmission parameters based on channel conditions.

`timescale 1ns/1ps

module AdaptiveErrorCorrection(
    input wire         reset_n,           // Active low reset
    input wire         clock,             // System clock
    input wire         rx_done_flag,      // Signal when reception is complete
    input wire [2:0]   error_flag,        // Current error flags from ErrorCheck
    input wire [1:0]   current_parity,    // Current parity setting
    input wire         enable_adaptation, // Enable/disable adaptive mechanism
    
    output reg [1:0]   optimal_parity,    // Recommended parity type
    output reg         retransmit_request, // Request retransmission
    output reg [7:0]   error_stats,       // Error statistics for monitoring
    output reg         adaptation_active  // Indicates adaptation is running
);

// Error tracking parameters
localparam ERROR_WINDOW_SIZE = 16;        // Window size for error rate calculation
localparam ADAPTATION_THRESHOLD = 4;     // Minimum errors before adaptation
localparam STABILITY_PERIOD = 32;        // Cycles to wait before next adaptation

// Parity type encoding (matching original system)
localparam NOPARITY = 2'b00,
           ODD      = 2'b01,
           EVEN     = 2'b10,
           NOPARITY_ALT = 2'b11;

// Internal registers for error tracking
reg [15:0] error_history;                 // Circular buffer for recent errors
reg [4:0]  error_count;                   // Count of errors in current window
reg [4:0]  window_position;               // Current position in error window
reg [7:0]  stability_counter;             // Counter for stability period
reg [1:0]  last_optimal_parity;           // Previous optimal parity setting

// Parity performance tracking
reg [7:0]  no_parity_errors;
reg [7:0]  odd_parity_errors;
reg [7:0]  even_parity_errors;
reg [7:0]  transmission_count;

// Error pattern analysis
reg [2:0]  dominant_error_type;           // Most frequent error type
reg [7:0]  parity_error_count;
reg [7:0]  start_error_count;
reg [7:0]  stop_error_count;

// State machine for adaptation control
reg [1:0]  adaptation_state;
localparam MONITORING = 2'b00,
           ANALYZING  = 2'b01,
           ADAPTING   = 2'b10,
           STABILIZING = 2'b11;

// Main adaptation logic
always @(posedge clock or negedge reset_n) begin
    if (~reset_n) begin
        // Reset all counters and states
        error_history <= 16'b0;
        error_count <= 5'b0;
        window_position <= 5'b0;
        stability_counter <= 8'b0;
        optimal_parity <= EVEN;           // Start with even parity
        last_optimal_parity <= EVEN;
        retransmit_request <= 1'b0;
        adaptation_active <= 1'b0;
        adaptation_state <= MONITORING;
        
        // Reset error tracking
        no_parity_errors <= 8'b0;
        odd_parity_errors <= 8'b0;
        even_parity_errors <= 8'b0;
        transmission_count <= 8'b0;
        
        // Reset error pattern analysis
        parity_error_count <= 8'b0;
        start_error_count <= 8'b0;
        stop_error_count <= 8'b0;
        dominant_error_type <= 3'b0;
        error_stats <= 8'b0;
    end
    else if (enable_adaptation) begin
        case (adaptation_state)
            MONITORING: begin
                adaptation_active <= 1'b1;
                
                // Process new transmission result
                if (rx_done_flag) begin
                    transmission_count <= transmission_count + 1'b1;
                    
                    // Update error history
                    error_history[window_position] <= |error_flag;
                    
                    // Update error counts based on current parity type
                    if (|error_flag) begin
                        case (current_parity)
                            NOPARITY, NOPARITY_ALT: no_parity_errors <= no_parity_errors + 1'b1;
                            ODD: odd_parity_errors <= odd_parity_errors + 1'b1;
                            EVEN: even_parity_errors <= even_parity_errors + 1'b1;
                        endcase
                        
                        // Track specific error types
                        if (error_flag[0]) parity_error_count <= parity_error_count + 1'b1;
                        if (error_flag[1]) start_error_count <= start_error_count + 1'b1;
                        if (error_flag[2]) stop_error_count <= stop_error_count + 1'b1;
                    end
                    
                    // Move to next position in circular buffer
                    window_position <= (window_position == ERROR_WINDOW_SIZE - 1) ? 5'b0 : window_position + 1'b1;
                    
                    // Calculate current error count in window
                    error_count <= count_errors_in_window(error_history);
                    
                    // Check if adaptation is needed
                    if (error_count >= ADAPTATION_THRESHOLD && transmission_count >= ERROR_WINDOW_SIZE) begin
                        adaptation_state <= ANALYZING;
                    end
                end
            end
            
            ANALYZING: begin
                // Determine dominant error type
                if (parity_error_count >= start_error_count && parity_error_count >= stop_error_count) begin
                    dominant_error_type <= 3'b001; // Parity errors dominant
                end
                else if (start_error_count >= stop_error_count) begin
                    dominant_error_type <= 3'b010; // Start bit errors dominant
                end
                else begin
                    dominant_error_type <= 3'b100; // Stop bit errors dominant
                end
                
                adaptation_state <= ADAPTING;
            end
            
            ADAPTING: begin
                // Determine optimal parity based on error patterns and performance
                case (dominant_error_type)
                    3'b001: begin // Parity errors dominant
                        // Switch to best performing parity type
                        if (even_parity_errors <= odd_parity_errors && even_parity_errors <= no_parity_errors) begin
                            optimal_parity <= EVEN;
                        end
                        else if (odd_parity_errors <= no_parity_errors) begin
                            optimal_parity <= ODD;
                        end
                        else begin
                            optimal_parity <= NOPARITY;
                        end
                    end
                    
                    3'b010, 3'b100: begin // Start/Stop bit errors dominant
                        // For framing errors, prefer stronger error detection
                        if (odd_parity_errors <= even_parity_errors) begin
                            optimal_parity <= ODD;
                        end
                        else begin
                            optimal_parity <= EVEN;
                        end
                    end
                    
                    default: begin
                        // Use best overall performer
                        if (no_parity_errors <= odd_parity_errors && no_parity_errors <= even_parity_errors) begin
                            optimal_parity <= NOPARITY;
                        end
                        else if (odd_parity_errors <= even_parity_errors) begin
                            optimal_parity <= ODD;
                        end
                        else begin
                            optimal_parity <= EVEN;
                        end
                    end
                endcase
                
                // Request retransmission if error rate is very high
                retransmit_request <= (error_count > (ERROR_WINDOW_SIZE >> 1));
                
                // Update error statistics for monitoring
                error_stats <= {error_count, dominant_error_type};
                
                adaptation_state <= STABILIZING;
                stability_counter <= 8'b0;
            end
            
            STABILIZING: begin
                // Wait for stability period before next adaptation
                stability_counter <= stability_counter + 1'b1;
                retransmit_request <= 1'b0; // Clear retransmit request
                
                if (stability_counter >= STABILITY_PERIOD) begin
                    // Reset counters for next adaptation cycle
                    parity_error_count <= 8'b0;
                    start_error_count <= 8'b0;
                    stop_error_count <= 8'b0;
                    error_count <= 5'b0;
                    
                    adaptation_state <= MONITORING;
                end
            end
        endcase
    end
    else begin
        adaptation_active <= 1'b0;
        retransmit_request <= 1'b0;
        // Maintain current optimal parity when adaptation is disabled
    end
end

// Function to count errors in the current window
function [4:0] count_errors_in_window;
    input [15:0] history;
    integer i;
    begin
        count_errors_in_window = 5'b0;
        for (i = 0; i < ERROR_WINDOW_SIZE; i = i + 1) begin
            count_errors_in_window = count_errors_in_window + history[i];
        end
    end
endfunction

// Additional monitoring outputs for debugging and analysis
always @(*) begin
    // Provide real-time error rate as percentage (approximation)
    if (transmission_count > 0) begin
        error_stats = (error_count * 8'd100) / ERROR_WINDOW_SIZE;
    end
    else begin
        error_stats = 8'b0;
    end
end

endmodule