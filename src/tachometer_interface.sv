module tachometer_interface #(parameter EDGE_COUNT_MAX = 300)(
  input  logic       clk_in          , // 125 MHz clock
  input  logic       reset_in        ,
  input  logic       tachometer_out_a,
  input  logic       tachometer_out_b,
  output logic [9:0] actual_rpm_out    // actual rpm of motor
);
  // 
  longint   unsigned clock_cycle_cnt;
  logic [$clog2(EDGE_COUNT_MAX+1)-1:0] edge_count;
  logic          prev_out_a     ;
  logic          prev_out_b     ;

  logic is_edge;
  assign is_edge = (tachometer_out_a ^ prev_out_a) | (tachometer_out_b ^ prev_out_b);
  // we are counting the total rising and falling edges of pulses every 10ms
  // using 4x decoding scheme RPM = (x pulses / 1440 pulses/rev / 0.01s )* (60s/1min) = 4.17 * x (pulses in 10ms)
  always_ff @(posedge clk_in or posedge reset_in) begin
    if(reset_in) begin
      edge_count      <= 0;
      prev_out_a      <= 0;
      prev_out_b      <= 0;
      clock_cycle_cnt <= 0;
      actual_rpm_out  <= 0;
    end else begin
      clock_cycle_cnt <= clock_cycle_cnt + 1;
      prev_out_a      <= tachometer_out_a;
      prev_out_b      <= tachometer_out_b;
      if (is_edge) edge_count <= edge_count + 1;
      if (clock_cycle_cnt >= (1250000-1)) begin
        edge_count <= 0;
        clock_cycle_cnt <= 0;
        actual_rpm_out  <= (edge_count<<2)+(edge_count>>3)+(edge_count>>5)+(edge_count>>7); // pulses * 100.0010101 = 4.16 * pulses ~ 4.17*pulses
      end
    end
  end
endmodule
