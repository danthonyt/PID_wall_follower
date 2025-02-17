module pid_controller #(
  parameter PID_PARAM_WIDTH_INT  = 8,
  parameter PID_PARAM_WIDTH_FRAC = 8,
  parameter SETPOINT_WIDTH       = 9
) (
  input  logic                                               clk              ,
  input  logic                                               reset            ,
  // proportional parameter
  input  logic [PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_p              ,
  // integral parameter
  input  logic [PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_i              ,
  // derivative parameter
  input  logic [PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_d              ,
  // target value
  input  logic [                         SETPOINT_WIDTH-1:0] setpoint         ,
  // actual value from sensor
  input  logic [                         SETPOINT_WIDTH-1:0] feedback         ,
  // corrected output
  output logic [                                       15:0] control_signal
);


  logic signed [                                         32:0] u_p, u_p_trunc;
  logic signed [                                         32:0] u_i, u_i_trunc;
  logic signed [                                         32:0] u_d, u_d_trunc;
  logic signed [1+PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_p_signed     ;
  logic signed [1+PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_i_signed     ;
  logic signed [1+PID_PARAM_WIDTH_INT-1:-PID_PARAM_WIDTH_FRAC] k_d_signed     ;
  logic signed [                         1+SETPOINT_WIDTH-1:0] setpoint_signed;
  logic signed [                         1+SETPOINT_WIDTH-1:0] feedback_signed;
  logic signed [                         1+SETPOINT_WIDTH-1:0] error          ;
  logic signed [                         1+SETPOINT_WIDTH-1:0] prev_error     ;
  assign k_p_signed      = {k_p[PID_PARAM_WIDTH_INT-1],k_p};
  assign k_i_signed      = {k_i[PID_PARAM_WIDTH_INT-1],k_i};
  assign k_d_signed      = {k_d[PID_PARAM_WIDTH_INT-1],k_d};
  assign setpoint_signed = {setpoint[SETPOINT_WIDTH-1] ,setpoint};
  assign feedback_signed = {feedback[SETPOINT_WIDTH-1] ,feedback};
  assign error           = setpoint_signed - feedback_signed;
  // 100 Hz clock enable
  logic clk_en;
  clk_enable #(.COUNT_WIDTH(21), .DIVISOR(1249999)) i_clk_enable (
    .clk_in  (clk  ),
    .reset_in(reset),
    .clk_en  (clk_en  )
  );

  always_ff @(posedge clk, posedge reset)
    begin
      if (reset)
        begin
          // proportional
          u_p               <= 0;
          // integral
          u_i               <= 0;
          // derivative
          u_d               <= 0;
          // final output
          control_signal <= setpoint;
          prev_error        <= 0;
        end
      else
        begin
          if (clk_en) begin

          end
        end
    end
  // proportional - u_p = k_p * error
  assign u_p               <= k_p_signed * error;
  // integral - u_i = u_i + k_i * del
  assign u_i               <= u_i + (k_i_signed * error);
  // derivative - u_d = k_d * (error[n] - error[n-1])
  assign u_d               <= k_d_signed * (error - prev_error);
  // final output
  assign control_signal <= u_p_trunc + u_i_trunc + u_d_trunc;
  assign prev_error        <= error;
endmodule
