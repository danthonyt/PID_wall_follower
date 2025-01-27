module pwm_tb;

  // Parameters
  localparam  R = 8;
  time CLK_PERIOD = 10ns;

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

initial begin
  duty = 128;
  dvsr = 0; // 390.625 khz
  reset = 1;
  #(CLK_PERIOD*3) reset = 0;
  #(2560ns + 15ns) 
  $finish;
end
endmodule