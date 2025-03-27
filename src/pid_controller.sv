module pid_controller #(
  parameter PID_INT_WIDTH = 8 ,
  parameter PV_WIDTH      = 9 ,
  parameter CONTROL_WIDTH = 16
) (
  input  logic                                   clk        ,
  input  logic                                   reset      ,
  input  logic                                   clk_en     ,
  input  logic                                   en         ,
  // proportional parameter
  input  logic unsigned [     PID_INT_WIDTH-1:0] k_p        ,
  // integral parameter
  input  logic unsigned [     PID_INT_WIDTH-1:0] k_i        ,
  // derivative parameter
  input  logic unsigned [     PID_INT_WIDTH-1:0] k_d        ,
  // target value
  input  logic unsigned [          PV_WIDTH-1:0] setpoint   ,
  // actual value from sensor
  input  logic unsigned [          PV_WIDTH-1:0] feedback   ,
  // corrected output add another bit for sign bit
  output logic signed   [     CONTROL_WIDTH-1:0] control_out,
  // signals to be sent for debugging
  output logic signed   [       ERROR_WIDTH-1:0] error      ,
  output logic signed   [PROPORTIONAL_WIDTH-1:0] u_p        ,
  output logic signed   [    INTEGRAL_WIDTH-1:0] u_i        ,
  output logic signed   [  DERIVATIVE_WIDTH-1:0] u_d
);
  localparam ERROR_WIDTH          = PV_WIDTH+1                     ;
  localparam PROPORTIONAL_WIDTH   = PID_INT_WIDTH + ERROR_WIDTH    ;
  localparam INTEGRAL_WIDTH       = PID_INT_WIDTH + ERROR_WIDTH    ;
  localparam DERIVATIVE_WIDTH     = PID_INT_WIDTH + ERROR_WIDTH + 1;
  localparam CONTROL_RAW_SIZE_INT = DERIVATIVE_WIDTH + 2           ;

  logic signed [ERROR_WIDTH-1:0] prev_error;
  logic signed [PID_INT_WIDTH:0] k_p_signed,k_i_signed,k_d_signed;
  // integral contribution of the current cycle (excludes previous accumulations)
  logic signed [      INTEGRAL_WIDTH-1:0] u_i_imm, prev_u_i, u_i_sat;
  logic signed [CONTROL_RAW_SIZE_INT-1:0] control_signal_raw,next_control_signal_raw;
  logic signed [       CONTROL_WIDTH-1:0] control_signal_adjusted;


  assign k_p_signed = {1'd0,k_p};
  assign k_i_signed = {1'd0,k_i};
  assign k_d_signed = {1'd0,k_d};

  always_ff @(posedge clk, posedge reset)
    begin
      if (reset) begin
        
        prev_u_i           <= 0;
        prev_error         <= 0;
        error      <= 0;
      end else if (~en) begin
       
        prev_u_i           <= 0;
        prev_error         <= 0;
        error      <= 0;
      end else if (clk_en) begin
        
        prev_u_i           <= ((error > -10) && (error < 10)) ? u_i : 0;
        prev_error         <= error;
        error      <= setpoint - feedback;
      end
    end

  assign u_p                     = k_p_signed * error;
  assign u_d                     = k_d_signed * (error - prev_error);
  assign u_i_imm                 = k_i_signed * error;
  assign control_signal_raw = u_p + u_i + u_d;
// antiwindup
// for this case only accumulate integral error when the robot is less than 5 cm away from the setpoint
  always_comb begin
    if ((error > -10) && (error < 10))
      u_i = u_i_sat;
    else
      u_i = 0;
  end
  saturating_adder_signed #(.DATA_WIDTH(INTEGRAL_WIDTH)) i_saturating_adder_signed (
    .a_in   (u_i_imm ),
    .b_in   (prev_u_i),
    .sum_out(u_i_sat )
  );


  localparam signed                                  WIDTH_DIFF              = CONTROL_WIDTH-CONTROL_RAW_SIZE_INT; // difference between control output size and control signal size before truncation
  generate
    if (WIDTH_DIFF == 0) begin
      // Widths are equal, direct assignment
      assign control_signal_adjusted = control_signal_raw[CONTROL_RAW_SIZE_INT-1:0];
    end else if (WIDTH_DIFF > 0) begin
      // adjusted size is bigger than the raw size, pad with sign bits
      assign control_signal_adjusted = {{(WIDTH_DIFF+1){control_signal_raw[CONTROL_RAW_SIZE_INT-1]}},control_signal_raw[CONTROL_RAW_SIZE_INT-2:0]};
    end else begin
      // adjusted size is smaller than the raw size, truncate and keep sign
      assign control_signal_adjusted = {control_signal_raw[CONTROL_RAW_SIZE_INT-1],control_signal_raw[CONTROL_WIDTH-2:0]};
    end
  endgenerate

  assign control_out = control_signal_adjusted;
endmodule

