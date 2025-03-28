module uart_tx_tb ();
	// Parameters
	time CLK_PERIOD = 8ns;

	logic clk;


	logic       reset    ;
	logic       start    ;
	logic [7:0] din      ;
	logic       serial_tx;
	logic       done     ;
	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk           ),
		.reset    (reset         ),
		.start    (start ),
		.din      (din   ),
		.serial_tx(serial_tx),
		.done     (done  )
	);

	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		start = 0;
		din  = 0;
		#CLK_PERIOD;
		reset = 0;
		start = 1;
		din = 8'hA7;
		#(CLK_PERIOD);
		start = 0;
		@(posedge done) #(CLK_PERIOD*10);
	end

endmodule