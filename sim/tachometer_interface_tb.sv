module tachometer_interface_tb ();

  // Parameters
  time CLK_PERIOD = 8ns; // 125 Mhz clock
  time SLOW_CLK_EN_PERIOD = 0.1ms; // 10 Khz clock enable
  //Ports
  logic        clk             ;
  logic        reset           ;
  logic        tachometer_pulse;
  logic [20:0] actual_rpm_out  ;
  tachometer_interface i_tachometer_interface (
    .clk_in             (clk             ),
    .reset_in           (reset           ),
    .tachometer_pulse_in(tachometer_pulse),
    .actual_rpm_out     (actual_rpm_out  )
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
      #(SLOW_CLK_EN_PERIOD*10);
      reset = 0;
      #SLOW_CLK_EN_PERIOD;
      // around 10 pulses in 10 ms for 300 rpm
        repeat(10) begin
          tachometer_pulse = 1;
          #(SLOW_CLK_EN_PERIOD);
          tachometer_pulse = 0;
          #(SLOW_CLK_EN_PERIOD);
        end

      #(SLOW_CLK_EN_PERIOD*100);
      $finish;
    end
endmodule
