module counter_tb ();
// Parameters
	time CLK_PERIOD = 8ns;
// 125 MHz system clock

	logic clk_tb;
	logic rst_tb;
	logic en_tb;
	int unsigned count_lim_tb;
	int unsigned count_tb;
	logic done_tb;
counter i_counter (.clk(clk_tb), .rst(rst_tb), .en(en_tb), .count_lim(count_lim_tb), .count(count_tb), .done(done_tb));



	initial begin
		clk_tb = 0;
		forever begin
			#(CLK_PERIOD/2)  clk_tb = ~ clk_tb ;
		end
	end
	initial begin
		rst_tb = 1;
		en_tb = 0;
		count_lim_tb = 0;
		#CLK_PERIOD; 
		@(posedge clk_tb);
		#(CLK_PERIOD/2);
		rst_tb = 0;
		en_tb = 1;
		count_lim_tb = 1250000;	// count for a period of 10 ms
		count_lim_tb = 125000000;	// 1s period
		//count_lim_tb = 4;	// count for a period of 32 ns
		@(posedge done_tb);
		$finish;
	end
endmodule