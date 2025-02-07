module pwm_tb;

  // Parameters
  localparam  R = 16;
  time CLK_PERIOD = 8ns;

  //Ports
  logic clk;
  logic reset;
  logic [R:0] duty;
  logic [31:0] dvsr;
  logic pwm_out;

  pwm # (
    .R(R)
  )
  pwm_inst (
    .clk(clk),
    .reset(reset),
    .duty(duty),
    .dvsr(dvsr),
    .pwm_out(pwm_out)
  );


initial begin
  clk = 0;
  forever begin
    #(CLK_PERIOD/2)  clk = ~ clk ;
  end
end
// divisor of 18 is approx 100 hz with R = 16
initial begin
  duty = 128;
  dvsr = 18; // approx 100 Hz about 100.6 Hz
  reset = 1;
  #(CLK_PERIOD*3) reset = 0;
  #(10ms) 
  $finish;
end
endmodule