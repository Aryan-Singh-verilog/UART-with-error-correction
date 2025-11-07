`timescale 1ns/1ps

// Fixed Power Management Unit
module PowerManager(
    input wire         reset_n,
    input wire         clock,
    input wire         power_enable,     // Global power enable
    input wire         tx_enable,        // TX unit enable
    input wire         rx_enable,        // RX unit enable
    input wire         tx_active,        // TX activity indicator
    input wire         rx_active,        // RX activity indicator
    input wire         send_request,     // TX send request
    input wire         data_received,    // RX data received
 
    input wire [1:0]   power_mode,       // 00: Normal, 01: Low Power, 10: Sleep, 11: Deep Sleep
    output reg         tx_clk_enable,    // Clock enable for TX
    output reg         rx_clk_enable,    // Clock enable for RX
    output reg         baud_clk_enable,  // Clock enable for baud generator
    output reg         power_good,       // Power status indicator
    output reg [1:0]   current_mode      // Current power mode
);
localparam NORMAL_MODE     = 2'b00,
           LOW_POWER_MODE  = 2'b01,
           SLEEP_MODE      = 2'b10,
           DEEP_SLEEP_MODE = 2'b11;

// State machine for proper power mode transitions
reg [1:0] next_mode;

// Power mode state machine - now uses clock for proper sequential logic
// **FIXED LOGIC**: Prioritize forced sleep modes over activity checks.
always @(posedge clock or negedge reset_n) begin
    if (~reset_n) begin
        current_mode <= DEEP_SLEEP_MODE;
    end
    else begin
        if (power_enable) begin
            // Forced sleep modes have the highest priority
            if (power_mode == SLEEP_MODE || power_mode == DEEP_SLEEP_MODE) begin
                current_mode <= power_mode;
            end
            // If not in a forced sleep, check for activity to decide between Normal and Low Power
            else if (tx_active || rx_active || send_request || data_received) begin
                current_mode <= NORMAL_MODE;
            end
            // Otherwise, default to the requested mode (e.g., Low Power)
            else begin
                current_mode <= power_mode;
            end
        end
        else begin
            current_mode <= DEEP_SLEEP_MODE;
        end
    end
end

// Clock enable logic based on power mode and activity
always @(*) begin
    next_mode = power_mode;
    if (~reset_n || ~power_enable) begin
        tx_clk_enable = 1'b0;
        rx_clk_enable = 1'b0;
        baud_clk_enable = 1'b0;
        power_good = 1'b0;
    end
    else begin
        case (current_mode)
            NORMAL_MODE: begin
                tx_clk_enable = tx_enable;
                rx_clk_enable = rx_enable;
                baud_clk_enable = tx_enable | rx_enable;
                power_good = 1'b1;
            end
            LOW_POWER_MODE: begin
                // Enable clocks only when there's activity
                tx_clk_enable = tx_enable & (tx_active | send_request);
                rx_clk_enable = rx_enable & (rx_active | data_received);
                baud_clk_enable = tx_clk_enable | rx_clk_enable;
                power_good = 1'b1;
            end
            SLEEP_MODE: begin
                // Only RX can wake up from sleep
                tx_clk_enable = 1'b0;
                rx_clk_enable = rx_enable & rx_active;
                baud_clk_enable = rx_clk_enable;
                power_good = 1'b1;
            end
            DEEP_SLEEP_MODE: begin
                tx_clk_enable = 1'b0;
                rx_clk_enable = 1'b0;
                baud_clk_enable = 1'b0;
                power_good = 1'b0;
            end
            default: begin
                tx_clk_enable = 1'b0;
                rx_clk_enable = 1'b0;
                baud_clk_enable = 1'b0;
                power_good = 1'b0;
            end
        endcase
    end
end

endmodule

// Fixed Clock Gating Cell - proper flip-flop based implementation
module ClockGate(
// ... (rest of the file is unchanged) ...
    input wire  clk_in,
    input wire  enable,
    input wire  reset_n,
    output wire clk_out
);
reg enable_ff;

// Use flip-flop instead of latch to avoid synthesis warnings
always @(negedge clk_in or negedge reset_n) begin
    if (~reset_n)
        enable_ff <= 1'b0;
    else
        enable_ff <= enable;
end

assign clk_out = clk_in & enable_ff & reset_n;
endmodule

module ErrorCheck(
    input wire         reset_n,       
    input wire         recieved_flag, 
    input wire         parity_bit,    
    input wire         start_bit,     
    input wire         stop_bit,      
    input wire   [1:0]  parity_type,   
    input wire  [7:0]  raw_data,      
    input wire         clk_enable,    // Power management
    output reg [2:0]   error_flag,
    output reg         parity_bit_out  
);
reg error_parity;
reg parity_flag;
reg start_flag;
reg stop_flag;

localparam ODD        = 2'b01,
           EVEN       = 2'b10,
           NOPARITY00 = 2'b00,
           NOPARITY11 = 2'b11;
// Combined parity calculation - only when enabled
always @(*) 
begin
    if (clk_enable) begin
        case (parity_type)
          NOPARITY00, NOPARITY11: begin
            error_parity = 1'b0;
            parity_bit_out = 1'b1;      
          end
          ODD: begin
            error_parity = (^raw_data == parity_bit) ? 1'b0 : 1'b1;
            parity_bit_out = ^raw_data;  
          end
          EVEN: begin
            error_parity = (^raw_data == parity_bit) ? 1'b1 : 1'b0;
            parity_bit_out = ~(^raw_data);  
          end
          default: begin
            error_parity = 1'b1;
            parity_bit_out = 1'b1;      
          end
        endcase
    end
    else begin
        error_parity = 1'b0;
        parity_bit_out = 1'b1;
    end
end

// Clock domain logic for error checking
always @(posedge recieved_flag or negedge reset_n) begin
  if (~reset_n) begin
    parity_flag  <= 1'b0;
    start_flag   <= 1'b0;
    stop_flag    <= 1'b0;
  end
  else if (clk_enable) begin
    if ((parity_type == NOPARITY00) || (parity_type == NOPARITY11)) begin
      parity_flag <= 1'b0;
    end
    else begin
      parity_flag <= error_parity;
    end
    start_flag  <= start_bit;  
    stop_flag   <= ~stop_bit;
  end
end

always @(*) 
begin
  if (clk_enable)
    error_flag = {stop_flag, start_flag, parity_flag};
  else
    error_flag = 3'b000;
end

endmodule

// Power-aware Baud Generator
module BaudGen(
    input wire         reset_n,     
    input wire         clock,       
    input wire  [1:0]  baud_rate,
    input wire         tx_mode,       
    input wire         clk_enable,   // Power management
    output reg         baud_clk     
);
wire gated_clock;
reg [13:0] final_value;  
reg [13:0] clock_ticks;  

localparam BAUD24  = 2'b00,
           BAUD48  = 2'b01,
           BAUD96  = 2'b10,
           BAUD192 = 2'b11;
// Clock gating for power savings
ClockGate cg_inst(
    .clk_in(clock),
    .enable(clk_enable),
    .reset_n(reset_n),
    .clk_out(gated_clock)
);
always @(*) 
begin
    if (tx_mode) begin
        case (baud_rate)
            BAUD24:  final_value = 14'd10417;
            BAUD48:  final_value = 14'd5208;   
            BAUD96:  final_value = 14'd2604;   
            BAUD192: final_value = 14'd1302;  
            default: final_value = 14'd2604;
        endcase
    end
    else begin
        case (baud_rate)
            BAUD24:  final_value = 14'd651;
            BAUD48:  final_value = 14'd326;     
            BAUD96:  final_value = 14'd163;     
            BAUD192: final_value = 14'd81;      
            default: final_value = 14'd163;
        endcase
    end
end

always @(posedge gated_clock or negedge reset_n) 
begin
  if(~reset_n) begin
    clock_ticks <= 14'd0;
    baud_clk    <= 1'b0;
  end
  else if (clk_enable) begin
    if(clock_ticks >= final_value) begin
      baud_clk    <= ~baud_clk;
      clock_ticks <= 14'd0;
    end
    else begin
      clock_ticks <= clock_ticks + 1'd1;
    end
  end
end

endmodule

module SIPO(
    input  wire         reset_n,        
    input  wire         data_tx,        
    input  wire         baud_clk,       
    input  wire         clk_enable,     // Power management
    output reg          active_flag,    
    output reg          recieved_flag,  
    output reg  [10:0]  data_parll      
);
reg [3:0]  frame_counter;
reg [3:0]  stop_count;
reg [1:0]  state;
localparam IDLE   = 2'b00,
           CENTER = 2'b01,
           FRAME  = 2'b10,
           HOLD   = 2'b11;
always @(posedge baud_clk or negedge reset_n) 
begin
  if (~reset_n) begin
    state <= IDLE;
    data_parll <= 11'b11111111111;
    stop_count <= 4'd0;
    frame_counter <= 4'd0;
    recieved_flag <= 1'b0;
    active_flag <= 1'b0;
  end
  else if (clk_enable) begin
    case (state)
      IDLE: begin
        data_parll <= 11'b11111111111;
        stop_count <= 4'd0;
        frame_counter <= 4'd0;
        recieved_flag <= 1'b0;
        if(~data_tx) begin
          state <= CENTER;
          active_flag <= 1'b1;
        end
        else begin
          active_flag <= 1'b0;
        end
      end

      CENTER: begin
        if(&stop_count[2:0]) begin
          data_parll[0] <= data_tx;
          stop_count <= 4'd0;
          state <= FRAME;
        end
        else begin
          stop_count <= stop_count + 1'b1;
        end
      end

      FRAME: begin
        if(frame_counter == 4'd10) begin
          frame_counter <= 4'd0;
          recieved_flag <= 1'b1;
          state <= HOLD;
          active_flag <= 1'b0;
        end
        else begin
          if(&stop_count) begin
            data_parll[frame_counter + 1'b1] <= data_tx;
            frame_counter <= frame_counter + 1'b1;
            stop_count <= 4'd0; 
          end
          else begin
            stop_count <= stop_count + 1'b1;
          end
        end
      end

      HOLD: begin
        if(&stop_count) begin
          frame_counter <= 4'd0;
          stop_count <= 4'd0; 
          recieved_flag <= 1'b0;
          state <= IDLE;
        end
        else begin
          stop_count <= stop_count + 1'b1;
        end
      end
    endcase
  end
end

endmodule

module PISO(
    input wire           reset_n,            
    input wire           send,               
    input wire           baud_clk,           
    input wire           parity_bit,         
    input wire [1:0]     parity_type,        
    input wire [7:0]     data_in,            
    input wire           clk_enable,         // Power management
    output reg 	         data_tx, 	         
	output reg 	         active_flag,        
	output reg  	     done_flag 	         
);
reg [3:0]   stop_count;
reg [10:0]  frame, frame_r;
reg         state;
localparam IDLE = 1'b0, ACTIVE = 1'b1;

// Frame construction
always @(*) begin
    if ((~|parity_type) || (&parity_type))
        frame = {2'b11, data_in, 1'b0};
    else
        frame = {1'b1, parity_bit, data_in, 1'b0};
end

always @(posedge baud_clk or negedge reset_n) begin
    if (~reset_n) begin
        state <= IDLE;
        data_tx <= 1'b1;
        active_flag <= 1'b0;
        done_flag <= 1'b1;
        stop_count <= 4'd0;
        frame_r <= 11'h7FF;
    end
	else if (clk_enable) begin
		case (state)
            IDLE: begin
                data_tx <= 1'b1;
                active_flag <= 1'b0;
                done_flag <= 1'b1;
                stop_count <= 4'd0;
                if (send) begin
                    frame_r <= frame;
                    state <= ACTIVE;
                end
            end

            ACTIVE: begin
                if (stop_count >= 4'd10) begin  
                    data_tx <= 1'b1;
                    stop_count <= 4'd0;
                    active_flag <= 1'b0;
                    done_flag <= 1'b1;
                    state <= IDLE;
                end
                else begin
                    data_tx <= frame_r[0];
                    frame_r <= frame_r >> 1;
                    stop_count <= stop_count + 1'b1;
                    active_flag <= 1'b1;
                    done_flag <= 1'b0;
                end
            end
        endcase 
	end 
end
endmodule  

module RxUnit(
    input wire         reset_n,      
    input wire         data_tx,      
    input wire         clock,        
    input wire  [1:0]  parity_type,  
    input wire  [1:0]  baud_rate,    
    input wire         clk_enable,   // Power management
    output wire        active_flag,
    output reg         done_flag,
    output wire [2:0]  error_flag,
    output reg  [7:0]  data_out
);
wire baud_clk_w, recieved_flag_w;          
wire [10:0] data_parll_w; 
wire def_par_bit_w, def_strt_bit_w, def_stp_bit_w;
BaudGen Unit1(
    .reset_n(reset_n),
    .clock(clock),
    .baud_rate(baud_rate),
    .tx_mode(1'b0),  // RX mode
    .clk_enable(clk_enable),
    .baud_clk(baud_clk_w)
);
SIPO Unit2(
    .reset_n(reset_n),
    .data_tx(data_tx),
    .baud_clk(baud_clk_w),
    .clk_enable(clk_enable),
    .active_flag(active_flag),
    .recieved_flag(recieved_flag_w),
    .data_parll(data_parll_w)
);
// Improved DeFrame functionality with power awareness
reg [7:0] last_valid_data;
wire data_valid;
wire gated_clock;
ClockGate cg_rx(
    .clk_in(clock),
    .enable(clk_enable),
    .reset_n(reset_n),
    .clk_out(gated_clock)
);
assign data_valid = (error_flag == 3'b000) && recieved_flag_w && clk_enable;
always @(posedge gated_clock or negedge reset_n) begin
  if (~reset_n) begin
    data_out <= 8'h00;
    last_valid_data <= 8'h00;
    done_flag <= 1'b0;
  end
  else if (clk_enable) begin
    if (data_valid) begin
      data_out <= data_parll_w[8:1];
      last_valid_data <= data_parll_w[8:1];
      done_flag <= 1'b1;
    end
    else if (recieved_flag_w && (error_flag != 3'b000)) begin
      data_out <= last_valid_data;
      done_flag <= 1'b0;
    end
    else begin
      done_flag <= 1'b0;
    end
  end
end

assign def_strt_bit_w = data_parll_w[0];
assign def_par_bit_w = data_parll_w[9];
assign def_stp_bit_w = data_parll_w[10];
ErrorCheck Unit4(
    .reset_n(reset_n),
    .recieved_flag(recieved_flag_w),
    .parity_bit(def_par_bit_w),
    .start_bit(def_strt_bit_w),
    .stop_bit(def_stp_bit_w),
    .parity_type(parity_type),
    .raw_data(data_parll_w[8:1]),
    .clk_enable(clk_enable),
    .error_flag(error_flag),
    .parity_bit_out()
);
endmodule

module TxUnit(
    input wire          reset_n,       
    input wire          send,          
    input wire          clock,         
    input wire  [1:0]   parity_type,   
    input wire  [1:0]   baud_rate,     
    input wire  [7:0]   data_in,       
    input wire          clk_enable,    // Power management
    output wire         data_tx,             
    output wire         active_flag,         
    output wire         done_flag            
);

wire parity_bit_w, baud_clk_w;
BaudGen Unit1(
    .reset_n(reset_n),
    .clock(clock),
    .baud_rate(baud_rate),
    .tx_mode(1'b1),  // TX mode
    .clk_enable(clk_enable),
    .baud_clk(baud_clk_w)
);
ErrorCheck Unit2(
    .reset_n(reset_n),
    .recieved_flag(1'b0),
    .parity_bit(1'b0),
    .start_bit(1'b0),
    .stop_bit(1'b0),
    .parity_type(parity_type),
    .raw_data(data_in),
    .clk_enable(clk_enable),
    .error_flag(),
    .parity_bit_out(parity_bit_w)
);
PISO Unit3(
    .reset_n(reset_n),
    .send(send),
    .baud_clk(baud_clk_w),
    .data_in(data_in),
    .parity_type(parity_type),
    .parity_bit(parity_bit_w),
    .clk_enable(clk_enable),
    .data_tx(data_tx),
    .active_flag(active_flag),
    .done_flag(done_flag)
);
endmodule

// Enhanced Duplex with Power Management - Fixed connections
module Duplex (
    input   wire         reset_n,       
    input   wire         send,          
    input   wire         clock,         
    input   wire  [1:0]  parity_type,   
    input   wire  [1:0]  baud_rate,     
    input   wire  [7:0]  data_in,       
    
    // Power Management Inputs
    input   wire         power_enable,      // Global power enable
    input   wire         tx_enable,         // TX unit enable
    input   wire         rx_enable,         // RX unit enable  
    input   wire  [1:0]  power_mode,        // Power mode selection
    
    output  wire         tx_active_flag, 
    output  wire         tx_done_flag,   
    output  wire         rx_active_flag, 
    output  wire         rx_done_flag,   
    output  wire  [7:0]  data_out,       
    output  wire  [2:0]  error_flag,
    
    // Power Management Outputs
    output  wire         power_good,        // Power status
    output  wire  [1:0]  current_power_mode, // Current power mode
    output  wire         tx_clk_enable,     // <-- ADDED
    output  wire         rx_clk_enable      // <-- ADDED
);
wire data_tx_w;        
wire tx_clk_enable_w, rx_clk_enable_w, baud_clk_enable_w;

// Assign internal wires to the new output ports
assign tx_clk_enable = tx_clk_enable_w; // <-- ADDED
assign rx_clk_enable = rx_clk_enable_w; // <-- ADDED

// Power Management Unit - Now properly connected
PowerManager pm_unit(
    .reset_n(reset_n),
    .clock(clock),                      // Connected clock
    .power_enable(power_enable),
    .tx_enable(tx_enable),
    .rx_enable(rx_enable),
    .tx_active(tx_active_flag),         // Connected tx_active
    .rx_active(rx_active_flag),         // Connected rx_active
    .send_request(send),                // Connected send_request
    .data_received(rx_done_flag),       // Connected data_received
    .power_mode(power_mode),            // Connected power_mode
    .tx_clk_enable(tx_clk_enable_w),
    .rx_clk_enable(rx_clk_enable_w),
    .baud_clk_enable(baud_clk_enable_w),
    .power_good(power_good),
    .current_mode(current_power_mode)
);
TxUnit Transmitter(
    .reset_n(reset_n),
    .send(send),
    .clock(clock),
    .parity_type(parity_type),
    .baud_rate(baud_rate),
    .data_in(data_in),
    .clk_enable(tx_clk_enable_w),
    .data_tx(data_tx_w),
    .active_flag(tx_active_flag),
    .done_flag(tx_done_flag)
);
RxUnit Receiver(
    .reset_n(reset_n),
    .clock(clock),
    .parity_type(parity_type),
    .baud_rate(baud_rate),
    .data_tx(data_tx_w),
    .clk_enable(rx_clk_enable_w),
    .data_out(data_out),
    .error_flag(error_flag),
    .active_flag(rx_active_flag),
    .done_flag(rx_done_flag)
);
endmodule