module adc_read_fsm_tb ();
	time        CLK_PERIOD                      = 8ns;
	logic       clk                                  ;
	logic       reset                                ;
	logic       i2c_transaction_done                 ;
	logic [7:0] i2c_master_dout           [0:2]      ;
	logic       i2c_transaction_start                ;
	logic       i2c_transaction_rd_nwr               ;
	logic [6:0] i2c_transaction_slave_addr           ;
	logic [7:0] i2c_master_din               [0:2]        ;
	logic  [$clog2(3+1)-1:0] i2c_transaction_bytes_num;
	adc_read_fsm #(.MAX_BYTES_PER_TRANSACTION(3)) i_adc_read_fsm (
		.clk                       (clk                       ),
		.reset                     (reset                     ),
		.i2c_transaction_done      (i2c_transaction_done      ),
		.i2c_master_dout           (i2c_master_dout           ),
		.i2c_transaction_start     (i2c_transaction_start     ),
		.i2c_transaction_rd_nwr    (i2c_transaction_rd_nwr    ),
		.i2c_transaction_slave_addr(i2c_transaction_slave_addr),
		.i2c_master_din            (i2c_master_din            ),
		.i2c_transaction_bytes_num (i2c_transaction_bytes_num )
	);

	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		i2c_transaction_done = 0;
		i2c_master_dout = {1,2,3};
		#(CLK_PERIOD*3);
		reset = 0;
		i2c_transaction_done = 1;
		#(CLK_PERIOD*100);
		#100ms;
		$finish;
	end
endmodule