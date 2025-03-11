module pid_controller #(
  parameter PID_INT_WIDTH  = 8,
  parameter PID_FRAC_WIDTH = 8,
  parameter SP_WIDTH       = 9
) (
  input  logic                                   clk           ,
  input  logic                                   reset         ,
  // proportional parameter
  input  logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_p           ,
  // integral parameter
  input  logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_i           ,
  // derivative parameter
  input  logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_d           ,
  // target value
  input  logic [                   SP_WIDTH-1:0] setpoint      ,
  // actual value from sensor
  input  logic [                   SP_WIDTH-1:0] feedback      ,
  // corrected output
  output logic [     3+SP_WIDTH+PID_INT_WIDTH:0] control_signal
);


  logic signed [  SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_p, u_p_trunc;
  logic signed [1+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_i, u_i_trunc;
  logic signed [1+SP_WIDTH+PID_INT_WIDTH:-PID_FRAC_WIDTH] u_d, u_d_trunc;
  logic signed [           PID_INT_WIDTH:-PID_FRAC_WIDTH] k_p_signed     ;
  logic signed [           PID_INT_WIDTH:-PID_FRAC_WIDTH] k_i_signed     ;
  logic signed [           PID_INT_WIDTH:-PID_FRAC_WIDTH] k_d_signed     ;
  logic signed [                              SP_WIDTH:0] setpoint_signed;
  logic signed [                              SP_WIDTH:0] feedback_signed;
  logic signed [                              SP_WIDTH:0] error          ;
  logic signed [                              SP_WIDTH:0] prev_error     ;

  // convert PID parameters to signed for error calculations
  assign k_p_signed      = {k_p[PID_INT_WIDTH-1],k_p};
  assign k_i_signed      = {k_i[PID_INT_WIDTH-1],k_i};
  assign k_d_signed      = {k_d[PID_INT_WIDTH-1],k_d};
  assign setpoint_signed = {setpoint[SP_WIDTH-1] ,setpoint};
  assign feedback_signed = {feedback[SP_WIDTH-1] ,feedback};
  assign error           = setpoint_signed - feedback_signed;

  // 100 Hz clock enable
  logic clk_en;
  clk_enable #(.COUNT_WIDTH(21), .DIVISOR(1249999)) i_clk_enable (
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
          control_signal <= setpoint;
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
            control_signal <= u_p_trunc + u_i_trunc + u_d_trunc;
            prev_error     <= error;
          end
        end
    end

endmodule
