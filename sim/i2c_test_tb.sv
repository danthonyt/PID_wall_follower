module i2c_test_tb ();

	logic clk;
	logic reset;
	logic scl_pin;
	logic sda_pin;
	logic [3:0] led;
i2c_test i_i2c_test (.clk(clk), .reset(reset), .scl_pin(scl_pin), .sda_pin(sda_pin), .led(led));

endmodule