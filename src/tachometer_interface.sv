module tachometer_interface (
  input  logic       clk_in             , // 125 MHz clock
  input  logic       clk_en             ,
  input  logic       reset_in           ,
  input  logic       tachometer_pulse_in, // pulse from tachometer
  output logic [9:0] actual_rpm_out       // actual rpm of motor
);
  int   unsigned rising_edge_cnt      ;
  int   unsigned clock_cycle_cnt      ;
  logic          prev_tachometer_pulse;
  // we are counting the number of pulses every 10ms
  // RPM = (x pulses  / 360 pulses/rev / 0.05 s) * ( 60 s / 1 min) = 3.33 * x rev/min is approx 2x + x + x/4 + x/16
  always_ff @(posedge clk_in or posedge reset_in) begin
    if(reset_in) begin
      rising_edge_cnt       <= 0;
      prev_tachometer_pulse <= 0;
      clock_cycle_cnt       <= 0;
      actual_rpm_out        <= 0;
    end else begin
      if (clk_en)begin
        clock_cycle_cnt       <= clock_cycle_cnt + 1;
        prev_tachometer_pulse <= tachometer_pulse_in;
        // every rising edge is another pulse
        if (tachometer_pulse_in && !prev_tachometer_pulse) rising_edge_cnt <= rising_edge_cnt + 1;
        // 500 clock cycles at 10 KHz = 50ms period 
        // maximum possible sampled RPM = max_clock_cycles/2 * 3.33 = 833 RPM
        // 500 CLOCK CYCLES = 50 MS
        if (clock_cycle_cnt == 500-1) begin
          clock_cycle_cnt <= 0;
          // RPM = 3.33 * num_pulses
          actual_rpm_out  <= (rising_edge_cnt<<1) + rising_edge_cnt + (rising_edge_cnt>>2) + (rising_edge_cnt>>4);
          rising_edge_cnt <= 0;
        end
      end
    end
  end
endmodule
