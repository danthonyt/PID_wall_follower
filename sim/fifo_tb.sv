module fifo_tb ();
// Parameters
	time CLK_PERIOD = 8ns;

	logic              clk             ;
	logic              rst             ;
	logic              wr_en           ;
	logic              rd_en           ;
	logic [DWIDTH-1:0] din             ;
	logic [DWIDTH-1:0] dout            ;
	logic              empty           ;
	logic              full            ;
	parameter          DEPTH_POW_2 = 10; // holds 1023 elements
	parameter          DWIDTH      = 16;
	fifo #(.DEPTH_POW_2(DEPTH_POW_2), .DWIDTH(DWIDTH)) i_fifo (
		.clk  (clk  ),
		.rst  (rst  ),
		.wr_en(wr_en),
		.rd_en(rd_en),
		.din  (din  ),
		.dout (dout ),
		.empty(empty),
		.full (full )
	);


	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		rst = 1;
		wr_en = 0;
		rd_en = 0;
		din = 0;
		@(posedge clk);
		#CLK_PERIOD;
		rst = 0;
		wr_en = 1;
		for (int i = 0; i < 2**DEPTH_POW_2-1; i++) begin
			din = i;
			#CLK_PERIOD;
		end
		wr_en = 0;
		rd_en = 1;
		din = 0;
		#CLK_PERIOD;
		for (int i = 0; i < 2**DEPTH_POW_2-1 ; i++) begin
			if (dout != i ) begin
				$display("INCORRECT DOUT VALUE! actual: %d, expected: %d",dout,i);
				$finish;
			end
			#CLK_PERIOD;
		end

		$display("TEST PASSED");
		$finish;
	end

endmodule