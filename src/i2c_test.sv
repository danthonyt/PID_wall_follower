module i2c_test (
	inout logic scl_pin,
	inout logic sda_pin,

	);

	logic clk;
	logic reset;
	logic transaction_start;
	logic rd_nwr;
	logic [6:0] slave_addr;
	logic [7:0] din[0:2];
	logic [$clog2(3+1)-1:0] transaction_bytes_num;
	logic [7:0] dout[0:2];
	logic transaction_done;
i2c_master #(.MAX_BYTES_PER_TRANSACTION(3)) i_i2c_master (
	.clk                  (clk                  ),
	.reset                (reset                ),
	.transaction_start    (transaction_start    ),
	.rd_nwr               (rd_nwr               ),
	.scl_pin              (scl_pin              ),
	.sda_pin              (sda_pin              ),
	.slave_addr           (slave_addr           ),
	.din                  (din                  ),
	.transaction_bytes_num(transaction_bytes_num),
	.dout                 (dout                 ),
	.transaction_done     (transaction_done     )
);
always_ff @(posedge clk or posedge reset) begin : proc_
	if(reset) begin
		 <= 0;
	end else begin
		 <= ;
		 // 4 LEDS 
		 // led 1 on if 0 - 1/4
		 // led 2 if 1/4 - 1/2
		 // led 3 if 1/2 to 3/4
		 // led 4 if 3/4 to 1
		 // i2c to write config reg 
		 // i2c to write select conversion reg
		 
		 // repeat 
		 // i2c to read conversion reg
	end
end
endmodule 