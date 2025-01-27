module pwm_tb;

  // Parameters
  localparam  R = 8;
  localparam CLK_PERIOD = 5;

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

always #(CLK_PERIOD)  clk = ! clk ;

initial begin
  duty = 128;
  dvsr = 1;
  reset = 1;
  #(CLK_PERIOD*3) reset = 0;
  #(CLK_PERIOD*2^R + 10);
  $finish;
end
endmodule