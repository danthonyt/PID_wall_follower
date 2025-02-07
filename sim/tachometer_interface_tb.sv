module tachometer_interface_tb;

  // Parameters
  localparam  R = 16;
  time CLK_PERIOD = 100ns;    // 10 Mhz clock
  //Ports
  logic clk;
  logic reset;
  logic tachometer_pulse;
  logic [20:0] rpm_meas_out;

  tachometer_interface  tachometer_interface_inst (
                          .clk_in(clk),
                          .reset_in(reset),
                          .tachometer_pulse(tachometer_pulse),
                          .rpm_meas_out(rpm_meas_out)
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
    #(CLK_PERIOD*1000);
    reset = 0;
    repeat (10)
    begin
      tachometer_pulse = 1;
      #(CLK_PERIOD*500);
      tachometer_pulse = 0;
      #(CLK_PERIOD*500);
    end
    reset = 1;
    #(CLK_PERIOD*3);
    $finish;
  end
endmodule
