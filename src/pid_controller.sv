module pid_controller #(
  parameter PID_FRAC_WIDTH = 8 ,
  parameter PV_WIDTH       = 9 ,
  parameter CONTROL_WIDTH  = 16
) (
  input  logic                                                       clk               ,
  input  logic                                                       reset             ,
  input  logic                                                       clk_en            ,
  input  logic                                                       en                ,
  // proportional parameter
  input  logic        [(CONTROL_WIDTH-PV_WIDTH-3)-1:-PID_FRAC_WIDTH] k_p               ,
  // integral parameter
  input  logic        [(CONTROL_WIDTH-PV_WIDTH-3)-1:-PID_FRAC_WIDTH] k_i               ,
  // derivative parameter
  input  logic        [(CONTROL_WIDTH-PV_WIDTH-3)-1:-PID_FRAC_WIDTH] k_d               ,
  // target value
  input  logic        [                                PV_WIDTH-1:0] setpoint          ,
  // actual value from sensor
  input  logic        [                                PV_WIDTH-1:0] feedback          ,
  output logic        [                                  PV_WIDTH:0] error             ,
  // corrected output add another bit for sign bit
  output logic signed [                           CONTROL_WIDTH-1:0] control_signal_out
);
  //PID_INT_WIDTH       = CONTROL_WIDTH-3-PV_WIDTH;
  logic signed [                               PV_WIDTH:-PID_FRAC_WIDTH] error_fp,prev_error_fp;
  logic signed [             (CONTROL_WIDTH-PV_WIDTH-3):-PID_FRAC_WIDTH] k_p_signed,k_i_signed,k_d_signed;
  logic signed [1+PV_WIDTH+(CONTROL_WIDTH-PV_WIDTH-3):-PID_FRAC_WIDTH*2] u_p                 ;
  logic signed [1+PV_WIDTH+(CONTROL_WIDTH-PV_WIDTH-3):-PID_FRAC_WIDTH*2] u_i                 ;
  logic signed [1+PV_WIDTH+(CONTROL_WIDTH-PV_WIDTH-3):-PID_FRAC_WIDTH*2] u_d                 ;
  logic signed [2+PV_WIDTH+(CONTROL_WIDTH-PV_WIDTH-3):-PID_FRAC_WIDTH*2] control_signal      ;
  logic signed [                                      CONTROL_WIDTH-1:0] control_signal_trunc;

  assign error      = $signed({1'd0,setpoint}) - $signed({1'd0,feedback});
  assign error_fp   = {error,{PID_FRAC_WIDTH{1'b0}}};
  assign k_p_signed = {1'd0,k_p};
  assign k_i_signed = {1'd0,k_i};
  assign k_d_signed = {1'd0,k_d};

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
          prev_error_fp  <= 0;
        end
      else
        begin
          if (clk_en) begin
            if(en) begin
              // proportional - u_p = k_p * error
              u_p            <= k_p_signed * error_fp;
              // integral - u_i = u_i + k_i * delta
              u_i            <= u_i + (k_i_signed * error_fp);
              // derivative - u_d = k_d * (error[n] - error[n-1])
              u_d            <= k_d_signed * (error_fp - prev_error_fp);
              // final output
              control_signal <= u_p + u_i + u_d;
              prev_error_fp  <= error_fp;
            end
          end
        end
    end
  assign control_signal_trunc = control_signal[CONTROL_WIDTH-1:0];  // cut off fractional part.
  assign control_signal_out   = control_signal_trunc;
endmodule
