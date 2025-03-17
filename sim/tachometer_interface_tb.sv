module tachometer_interface_tb ();

  // Parameters
  time CLK_PERIOD = 8ns; // 125 Mhz clock
  //Ports
  logic        clk             ;
  logic        reset           ;
  logic        tachometer_pulse;
  logic [9:0] actual_rpm_out  ;
tachometer_interface i_tachometer_interface (
  .clk_in             (clk             ),
  .clk_en             (clk_en_10khz             ),
  .reset_in           (reset           ),
  .tachometer_pulse_in(tachometer_pulse),
  .actual_rpm_out     (actual_rpm_out     ) // TODO: Check connection ! Signal/port not matching : Expecting logic [9:0]  -- Found logic [20:0] 
);
// 10 KHz clock enable
  logic clk_en_10khz;
  clk_enable #(.DIVISOR(12499)) i_clk_enable_10khz (
    .clk_in  (clk         ),
    .reset_in(reset       ),
    .clk_en  (clk_en_10khz)
  );



  initial
    begin
      clk = 0;
      forever
        begin
          #(CLK_PERIOD/2)  clk = ~ clk ;
        end
    end
  initial
    begin
      reset = 1;
      tachometer_pulse = 0;
      #CLK_PERIOD;
      reset = 0;
      @(posedge clk_en_10khz);
      reset = 0;
      @(posedge clk_en_10khz);
      // around 100 pulses in 50 ms for 333 rpm
        repeat(100) begin
          tachometer_pulse = 1;
          @(posedge clk_en_10khz);
          tachometer_pulse = 0;
          @(posedge clk_en_10khz);
        end
        repeat(400) @(posedge clk_en_10khz);
      $finish;
    end
endmodule
