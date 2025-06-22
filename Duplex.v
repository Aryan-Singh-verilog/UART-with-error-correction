//  AUTHOR: Enhanced by AI Assistant based on Mohamed Maged Elkholy's work.
//  FILE NAME: EnhancedDuplex.v
//  TYPE: module.
//  KEYWORDS: UART, Full duplex, Adaptive, Machine Learning.
//  PURPOSE: An enhanced RTL modelling for duplex UART with adaptive error correction
//  that dynamically optimizes transmission parameters based on channel conditions.

`timescale 1ns/1ps

module Duplex (
    input   wire         reset_n,           // Active low reset
    input   wire         send,              // Enable to start sending data
    input   wire         clock,             // Main system clock
    input   wire  [1:0]  manual_parity_type,// Manual parity type setting
    input   wire  [1:0]  baud_rate,         // Baud rate setting
    input   wire  [7:0]  data_in,           // Data input
    input   wire         enable_adaptation, // Enable adaptive error correction
    input   wire         force_retransmit,  // Force retransmission
    
    output  wire         tx_active_flag,    // Transmitter active
    output  wire         tx_done_flag,      // Transmission complete
    output  wire         rx_active_flag,    // Receiver active
    output  wire         rx_done_flag,      // Reception complete
    output  wire  [7:0]  data_out,          // Received data
    output  wire  [2:0]  error_flag,        // Error flags
    output  wire  [1:0]  current_parity_type, // Current parity in use
    output  wire         retransmit_needed, // Retransmission recommended
    output  wire  [7:0]  error_statistics,  // Error statistics
    output  wire         adaptation_active, // Adaptive mode status
    output  wire         data_valid         // Indicates valid data output
);

// Internal wires and registers
wire        data_tx_w;              // Serial data connection
wire [1:0]  optimal_parity_w;       // Optimal parity from adaptation module
wire        retransmit_request_w;   // Retransmit request from adaptation
wire [7:0]  error_stats_w;          // Error statistics from adaptation
wire        adaptation_active_w;    // Adaptation status

// Parity type selection logic
reg [1:0]   selected_parity_type;
reg         retransmit_pending;
reg [2:0]   retransmit_counter;
reg         data_valid_reg;

// Parity type multiplexer - choose between manual and adaptive
always @(*) begin
    if (enable_adaptation) begin
        selected_parity_type = optimal_parity_w;
    end
    else begin
        selected_parity_type = manual_parity_type;
    end
end

// Retransmission control logic
always @(posedge clock or negedge reset_n) begin
    if (~reset_n) begin
        retransmit_pending <= 1'b0;
        retransmit_counter <= 3'b0;
        data_valid_reg <= 1'b0;
    end
    else begin
        // Handle retransmission requests
        if (retransmit_request_w || force_retransmit) begin
            retransmit_pending <= 1'b1;
            retransmit_counter <= 3'b0;
        end
        else if (retransmit_pending && tx_done_flag) begin
            retransmit_counter <= retransmit_counter + 1'b1;
            // Clear retransmit after successful transmission
            if (retransmit_counter >= 3'd2) begin // Allow 2 retransmissions
                retransmit_pending <= 1'b0;
            end
        end
        
        // Data validity control - only mark data as valid if no errors detected
        if (rx_done_flag) begin
            data_valid_reg <= ~|error_flag; // Valid if no errors
        end
        else if (send) begin
            data_valid_reg <= 1'b0; // Reset on new transmission
        end
    end
end

// Transmitter unit instance
TxUnit Transmitter(
    // Inputs
    .reset_n(reset_n),
    .send(send || retransmit_pending),  // Send original data or retransmit
    .clock(clock),
    .parity_type(selected_parity_type), // Use adaptive or manual parity
    .baud_rate(baud_rate),
    .data_in(data_in),

    // Outputs
    .data_tx(data_tx_w),
    .active_flag(tx_active_flag),
    .done_flag(tx_done_flag)
);

// Receiver unit instance
RxUnit Receiver(
    // Inputs
    .reset_n(reset_n),
    .clock(clock),
    .parity_type(selected_parity_type), // Use same parity as transmitter
    .baud_rate(baud_rate),
    .data_tx(data_tx_w),

    // Outputs
    .data_out(data_out),
    .error_flag(error_flag),
    .active_flag(rx_active_flag),
    .done_flag(rx_done_flag)
);

// Adaptive error correction unit instance
AdaptiveErrorCorrection Adapter(
    // Inputs
    .reset_n(reset_n),
    .clock(clock),
    .rx_done_flag(rx_done_flag),
    .error_flag(error_flag),
    .current_parity(selected_parity_type),
    .enable_adaptation(enable_adaptation),
    
    // Outputs
    .optimal_parity(optimal_parity_w),
    .retransmit_request(retransmit_request_w),
    .error_stats(error_stats_w),
    .adaptation_active(adaptation_active_w)
);

// Output assignments
assign current_parity_type = selected_parity_type;
assign retransmit_needed = retransmit_request_w || retransmit_pending;
assign error_statistics = error_stats_w;
assign adaptation_active = adaptation_active_w;
assign data_valid = data_valid_reg;

endmodule