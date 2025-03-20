module adc_lut_tb ();
	time CLK_PERIOD = 8ns;
	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end

	logic clk;
	logic reset;
	logic [15:0] raw_adc_data;
	logic [6:0] distance_cm_out;
adc_lut i_adc_lut (.clk(clk), .reset(reset), .raw_adc_data(raw_adc_data), .distance_cm_out(distance_cm_out));

	initial begin
		reset = 1;
		#(CLK_PERIOD) reset = 0;
		repeat(100) begin
			raw_adc_data <= $random();
			#(CLK_PERIOD*2);
		end
		$finish;
	end
endmodule