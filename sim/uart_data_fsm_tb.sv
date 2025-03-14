module uart_data_fsm_tb ();
	// Parameters
	time  CLK_PERIOD = 8ns;
	logic clk             ;
	logic reset           ;
	logic fsm_en          ;
	logic serial_tx       ;
		uart_data_fsm i_uart_data_fsm (.clk(clk), .reset(reset), .fsm_en(fsm_en), .serial_tx(serial_tx)); 

	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end

	initial begin
		reset = 1;
	    fsm_en = 0;
	    #(CLK_PERIOD*10);
	    reset = 0;
	    fsm_en = 1;
	    repeat(16) begin 
	    	@(posedge i_uart_data_fsm.uart_tx_done);
	    end 

	    $finish;

	end

endmodule