module pid_controller #(
  parameter PID_INT_WIDTH  = 8 ,
  parameter PID_FRAC_WIDTH = 8 ,
  parameter SP_WIDTH       = 9 ,
  parameter PID_OUT_WIDTH  = 16
) (
  input  logic                                          clk               ,
  input  logic                                          reset             ,
  // proportional parameter
  input  logic        [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_p               ,
  // integral parameter
  input  logic        [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_i               ,
  // derivative parameter
  input  logic        [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_d               ,
  // target value
  input  logic        [                   SP_WIDTH-1:0] setpoint          ,
  // actual value from sensor
  input  logic        [                   SP_WIDTH-1:0] feedback          ,
  // corrected output
  output logic signed [              PID_OUT_WIDTH-1:0] control_signal_out
);



  logic signed [PID_INT_WIDTH:-PID_FRAC_WIDTH] k_p_signed     ;
  logic signed [PID_INT_WIDTH:-PID_FRAC_WIDTH] k_i_signed     ;
  logic signed [PID_INT_WIDTH:-PID_FRAC_WIDTH] k_d_signed     ;
  logic signed [     SP_WIDTH:-PID_FRAC_WIDTH] setpoint_signed;
  logic signed [     SP_WIDTH:-PID_FRAC_WIDTH] feedback_signed;
  logic signed [     SP_WIDTH:-PID_FRAC_WIDTH] error          ;
  logic signed [     SP_WIDTH:-PID_FRAC_WIDTH] prev_error     ;


  logic signed [1+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_p           ;
  logic signed [2+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_i           ;
  logic signed [2+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_d           ;
  logic signed [3+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] control_signal;

  // convert PID parameters to signed for error calculations
  assign k_p_signed      = {1'b0,k_p};
  assign k_i_signed      = {1'b0,k_i};
  assign k_d_signed      = {1'b0,k_d};
  assign setpoint_signed = {1'b0 ,setpoint,{PID_FRAC_WIDTH{1'b0}}};
  assign feedback_signed = {1'b0 ,feedback,{PID_FRAC_WIDTH{1'b0}}};
  assign error           = setpoint_signed - feedback_signed;

  // 100 Hz clock enable
  logic clk_en;
  clk_enable #(.DIVISOR(1249999)) i_clk_enable (
    .clk_in  (clk   ),
    .reset_in(reset ),
    .clk_en  (clk_en)
  );

  always_ff @(posedge clk, posedge reset)
    begin
      if (reset)
        begin
          // proportional
          u_p            <= 0;
          // integral
          u_i            <= 0;
          // derivative
          u_d            <= 0;
          // final output
          control_signal <= 0;
          prev_error     <= 0;
        end
      else
        begin
          if (clk_en) begin
            // proportional - u_p = k_p * error
            u_p            <= k_p_signed * error;
            // integral - u_i = u_i + k_i * delta
            u_i            <= u_i + (k_i_signed * error);
            // derivative - u_d = k_d * (error[n] - error[n-1])
            u_d            <= k_d_signed * (error - prev_error);
            // final output
            control_signal <= u_p + u_i + u_d;
            prev_error     <= error;
          end
        end
    end
  assign control_signal_out = {control_signal[3+SP_WIDTH+PID_INT_WIDTH],control_signal[PID_OUT_WIDTH-2:0]};
endmodule
