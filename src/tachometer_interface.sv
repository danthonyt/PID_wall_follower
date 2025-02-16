module tachometer_interface (
  input  logic       clk_in             , // 125 MHz clock
  input  logic       reset_in           ,
  input  logic       tachometer_pulse_in, // pulse from tachometer
  output logic [8:0] actual_rpm_out       // actual rpm of motor
);
  logic [ 4:0] rising_edge_cnt              ;
  logic [ 4:0] clock_cycle_cnt              ;
  logic        prev_tachometer_pulse        ;
  // 1.8 KHz clock enable
  logic clk_en;
clk_enable #(.COUNT_WIDTH(17), .DIVISOR(69443)) i_clk_enable (.clk_in(clk_in), .reset_in(reset_in), .clk_en(clk_en));

  // we are counting the number of pulses every 10ms
  // RPM = (x pulses  / 360 pulses/rev / 0.01 s) * ( 60 s / 1 min) = 16.67 * x rev/min = 16x + x/2 + x/6
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
        // 18 clock cycles at 1.8 KHz = 10ms period which is 10 times faster than the time constant of the DC motor, same speed we will run the PID controller
        if (clock_cycle_cnt == 18-1) begin
          clock_cycle_cnt <= 0;
          // RPM = 16.6667 * num_pulses
          actual_rpm_out  <= (rising_edge_cnt<<4) + (rising_edge_cnt>>1) + (rising_edge_cnt>>1)* (1/3);
          rising_edge_cnt <= 0;
        end
      end
    end
  end
endmodule
