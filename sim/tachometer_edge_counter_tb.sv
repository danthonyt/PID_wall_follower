module tachometer_edge_counter_tb ();
  parameter EDGE_COUNT_MAX = 500;
  // Parameters
  time CLK_PERIOD = 8ns; // 125 Mhz clock
  //Ports
  logic       clk             ;
  logic       reset           ;
  logic       tachometer_out_a;
  logic       tachometer_out_b;
  logic [$clog2(300+1)-1:0] edge_count_o;
tachometer_edge_counter i_tachometer_edge_counter (
  .clk_in          (clk          ),
  .reset_in        (reset        ),
  .tachometer_out_a(tachometer_out_a),
  .tachometer_out_b(tachometer_out_b),
  .edge_count_o    (edge_count_o    )
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
      // 6 pulses in 10 ms means 24 edges
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
      @(i_tachometer_edge_counter.clock_cycle_cnt==0);
      #(CLK_PERIOD*10);
      $finish;
    end
endmodule
