module tachometer_interface (
  input  logic        clk_in             , // 125 MHz clock
  input  logic        reset_in           ,
  input  logic        tachometer_pulse_in, // pulse from tachometer
  output logic [20:0] actual_rpm_out       // actual rpm of motor
);
  logic [23:0] rising_edge_cnt      ;
  logic [23:0] clock_cycle_cnt      ;
  logic        prev_tachometer_pulse;
  // RPM = (x pulses  / 360 pulses/rev / 0.1 s) * ( 60 s / 1 min) = 1.67 * x rev/min = x + x/2 + x/6
  // Current State Logic -- sequential logic
  always_ff @(posedge clk_in or posedge reset_in) begin : proc_
    if(reset_in) begin
      rising_edge_cnt       <= 0;
      prev_tachometer_pulse <= 0;
      clock_cycle_cnt       <= 0;
      actual_rpm_out        <= 0;
    end else begin
      clock_cycle_cnt       <= clock_cycle_cnt + 1;
      prev_tachometer_pulse <= tachometer_pulse_in;
      if (tachometer_pulse_in && !prev_tachometer_pulse) rising_edge_cnt <= rising_edge_cnt + 1;
      if (clock_cycle_cnt == 12500000-1) begin
        clock_cycle_cnt <= 0;
        actual_rpm_out  <= rising_edge_cnt + rising_edge_cnt/2 + rising_edge_cnt /6;
        rising_edge_cnt <= 0;
      end
    end
  end
endmodule
