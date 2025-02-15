module tachometer_interface_tb ();

  // Parameters
  time CLK_PERIOD = 8ns; // 125 Mhz clock
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
      #(CLK_PERIOD*100);
      reset = 0;
      // around 180 pulses in 100 ms for 300 rpm
        repeat(180) begin
          tachometer_pulse = 1;
          #(CLK_PERIOD*30);
          tachometer_pulse = 0;
          #(CLK_PERIOD*70);
        end

      #(CLK_PERIOD*12500000);
      $finish;
    end
endmodule
