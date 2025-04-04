module adc_lut_tb ();
	time CLK_PERIOD = 8ns;
	logic clk  ;
	logic reset;
	logic signed [15:0] adc_data_diag;
	logic        [ 6:0] distance_diag;
	adc_lut i_adc_lut (.clk(clk), .reset(reset), .adc_data_diag(adc_data_diag), .distance_diag(distance_diag)); 
	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		#(CLK_PERIOD) reset = 0;
		repeat(100) begin
			adc_data_diag <= $random();
			#(CLK_PERIOD*2);
		end
		// max positive vaule
		adc_data_diag = 16'h7FFF;
		#(CLK_PERIOD*2);
		// zero
		adc_data_diag = 16'h0000;
		#(CLK_PERIOD*2);
		// max negative value
		adc_data_diag = 16'h8000;
		#(CLK_PERIOD*2);

		$finish;
	end
endmodule