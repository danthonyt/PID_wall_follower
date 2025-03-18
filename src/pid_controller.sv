module pid_controller #(
  parameter PID_INT_WIDTH  = 8 ,
  parameter PID_FRAC_WIDTH = 8 ,
  parameter PV_WIDTH       = 9 ,
  parameter CONTROL_WIDTH  = 16
) (
  input  logic                                            clk        ,
  input  logic                                            reset      ,
  input  logic                                            clk_en     ,
  input  logic                                            en         ,
  // proportional parameter
  input  logic unsigned [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_p        ,
  // integral parameter
  input  logic unsigned [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_i        ,
  // derivative parameter
  input  logic unsigned [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] k_d        ,
  // target value
  input  logic unsigned [                   PV_WIDTH-1:0] setpoint   ,
  // actual value from sensor
  input  logic unsigned [                   PV_WIDTH-1:0] feedback   ,
  output logic signed   [                     PV_WIDTH:0] error      ,
  // corrected output add another bit for sign bit
  output logic signed   [              CONTROL_WIDTH-1:0] control_out
);

  
  localparam                                         U_SIZE_INT              = PV_WIDTH+PID_INT_WIDTH-1          ;
  localparam                                         U_SIZE_FRAC             = PID_FRAC_WIDTH*2                  ;
  localparam                                         CONTROL_RAW_SIZE_INT    = U_SIZE_INT+1                      ;
  localparam signed                                             WIDTH_DIFF              = CONTROL_WIDTH-CONTROL_RAW_SIZE_INT; // difference between control output size and control signal size before truncation
  logic            signed [           PV_WIDTH:-PID_FRAC_WIDTH] error_fp,prev_error_fp;
  logic            signed [      PID_INT_WIDTH:-PID_FRAC_WIDTH] k_p_signed,k_i_signed,k_d_signed;
  logic            signed [          U_SIZE_INT-1:-U_SIZE_FRAC] u_p                                                         ;
  logic            signed [          U_SIZE_INT-1:-U_SIZE_FRAC] u_i                                                         ;
  logic            signed [          U_SIZE_INT-1:-U_SIZE_FRAC] u_d                                                         ;
  logic            signed [CONTROL_RAW_SIZE_INT-1:-U_SIZE_FRAC] control_signal_raw                                          ;
  logic            signed [                  CONTROL_WIDTH-1:0] control_signal_adjusted                                     ;

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
          u_p                <= 0;
          // integral
          u_i                <= 0;
          // derivative
          u_d                <= 0;
          // final output
          control_signal_raw <= 0;
          prev_error_fp      <= 0;
        end
      else
        begin
          if (clk_en) begin
            if(en) begin
              // proportional - u_p = k_p * error
              u_p                <= k_p_signed * error_fp;
              // integral - u_i = u_i + k_i * delta
              u_i                <= u_i + (k_i_signed * error_fp);
              // derivative - u_d = k_d * (error[n] - error[n-1])
              u_d                <= k_d_signed * (error_fp - prev_error_fp);
              // final output
              control_signal_raw <= u_p + u_i + u_d;
              prev_error_fp      <= error_fp;
            end
          end
        end
    end

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

