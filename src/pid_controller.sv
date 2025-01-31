module pid_controller 
#(
    parameter DATA_LENGTH = 32
)
(
    input logic clk,
    input logic reset,
    // number of cycles per operation
    input logic cycle_incr,
    // proportional parameter
    input logic [DATA_LENGTH-1:0] k_p,
    // integral parameter
    input logic [DATA_LENGTH-1:0] k_i,
    // derivative parameter
    input logic [DATA_LENGTH-1:0] k_d,
    // target
    input logic [DATA_LENGTH-1:0] set_point_input,
    // actual value from sensor
    input logic [DATA_LENGTH-1:0] meas_process_variable_input,
    // corrected output
    output logic [DATA_LENGTH-1:0] controller_output
  );

  logic [DATA_LENGTH-1:0] u_p, u_i, u_d;
  logic [DATA_LENGTH-1:0] curr_error, prev_error;
  assign curr_error = set_point_input - meas_process_variable_input;
  always_ff @(posedge clk, posedge reset)
  begin
    if (reset)
    begin
      // proportional
      u_p <= 0;
      // integral
      u_i <= 0;
      // derivative
      u_d <= 0;
      // final output
      controller_output <= set_point_input;
    end
    else
    begin
      // proportional
      u_p <= k_p * curr_error;
      // integral
      u_i <= u_i + (k_i * curr_error * cycle_incr);
      // derivative
      u_d <= k_d * (curr_error - prev_error) / cycle_incr;
      // final output
      controller_output <= u_p + u_i + u_d;
    end

  end
endmodule
