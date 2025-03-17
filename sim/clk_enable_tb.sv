module clk_enable_tb ();
// Parameters
	time CLK_PERIOD = 8ns;
// 125 MHz system clock
	logic clk_tb          ;
	logic reset_tb        ;
	logic clk_100_hz_en_tb, clk_10_khz_en_tb;

// 100 Hz clock enable
	clk_enable #(.DIVISOR(1249999)) i_clk_enable_100_hz (
		.clk_in  (clk_tb          ),
		.reset_in(reset_tb        ),
		.clk_en  (clk_100_hz_en_tb)
	);
// 10 KHz clock enable
	clk_enable #(.DIVISOR(12499)) i_clk_enable_1_8_khz (.clk_in(clk_tb), .reset_in(reset_tb), .clk_en(clk_10_khz_en_tb));

	initial begin
		clk_tb = 0;
		forever begin
			#(CLK_PERIOD/2)  clk_tb = ~ clk_tb ;
		end
	end
	initial begin
		reset_tb = 1;
		#(CLK_PERIOD*3) reset_tb = 0;
		#(CLK_PERIOD*1249999*2);
		#(CLK_PERIOD*3);
		$finish;
	end
endmodule

