module tachometer_interface_tb ();
  parameter EDGE_COUNT_MAX = 500;
  // Parameters
  time CLK_PERIOD = 8ns; // 125 Mhz clock
  //Ports
  logic       clk             ;
  logic       reset           ;
  logic       tachometer_out_a;
  logic       tachometer_out_b;
  logic [9:0] actual_rpm_out  ;
  tachometer_interface #(.EDGE_COUNT_MAX(EDGE_COUNT_MAX)) i_tachometer_interface (
    .clk_in          (clk             ),
    .reset_in        (reset           ),
    .tachometer_out_a(tachometer_out_a),
    .tachometer_out_b(tachometer_out_b),
    .actual_rpm_out  (actual_rpm_out  )
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
      tachometer_out_a = 0;
      tachometer_out_b = 1;
      #CLK_PERIOD;
      reset = 0;
      @(posedge clk);
      // around 6 pulses in 10 ms for 4.17*(6*4) = 
      repeat(6) begin
        tachometer_out_a = 1;
        #(CLK_PERIOD*3);
        tachometer_out_b = 0;
        #(CLK_PERIOD*3);
        tachometer_out_a = 0;
        #(CLK_PERIOD*3);
        tachometer_out_b = 1;
        #(CLK_PERIOD*3);
      end
      @(i_tachometer_interface.clock_cycle_cnt==0);
      $finish;
    end
endmodule
