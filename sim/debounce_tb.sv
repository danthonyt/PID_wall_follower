module debounce_tb();
		time CLK_PERIOD = 8ns;

	logic clk;
	logic reset;
	logic pb_in;
	logic pb_out;
debounce i_debounce (.clk(clk), .reset(reset), .pb_in(pb_in), .pb_out(pb_out));

	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end


	initial begin
		reset = 1;
		pb_in = 0;
		#(CLK_PERIOD) reset = 0;
		pb_in = 1;
		#(CLK_PERIOD*2);
		#40ms;
		pb_in = 0;
		#(CLK_PERIOD*2);
		pb_in = 1;
		#(CLK_PERIOD*2);
		#30ms;
		pb_in = 0;
		#(CLK_PERIOD*2);
		pb_in = 1;
		#20ms;
		pb_in = 0;
		#(CLK_PERIOD*2);
		pb_in = 1;
		
		#10ms;
		pb_in = 0;
		#CLK_PERIOD;
		pb_in = 1;
		#(CLK_PERIOD*10);
		pb_in = 0;
		#(CLK_PERIOD*10);
	

		$finish;
	end
endmodule