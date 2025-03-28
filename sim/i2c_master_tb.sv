module i2c_master_tb ();
// Parameters
	time CLK_PERIOD = 8ns;
	localparam LOW_CYCLES          = 672;
	localparam HIGH_CYCLES         = 577;
	localparam MAX_BYTES_PER_TRANSACTION = 3;
	logic clk;
	logic reset;
	logic sda_drive;
	logic sda_wr_en;
	logic scl_wr_en;


	logic transaction_start;
	logic rd_nwr;
	wire scl_pin;
	wire sda_pin;
	logic [6:0] slave_addr;
	logic [7:0] din[0:MAX_BYTES_PER_TRANSACTION-1];
	logic [$clog2(3+1)-1:0] transaction_bytes_num;
	logic [7:0] dout[0:MAX_BYTES_PER_TRANSACTION-1];
	logic transaction_done;
i2c_master #(.MAX_BYTES_PER_TRANSACTION(MAX_BYTES_PER_TRANSACTION)) i_i2c_master (
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



	assign scl_pin = ~scl_wr_en ? 1'b1 : 1'bz;	// should be driven high if nothing is controlling scl
	assign sda_pin = ~sda_wr_en ? sda_drive : 1'bz;	// modify this in tb based on what we expect, i.e. ack, nack, or data bits
	assign sda_wr_en = i_i2c_master.sda_wr_en;
	assign scl_wr_en = i_i2c_master.scl_wr_en;

task i2c_write;
	input  logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] num_bytes;
	input  logic [6:0] device_address;
	input  logic [7:0] transaction_msg[0:MAX_BYTES_PER_TRANSACTION-1];
	begin
		slave_addr = device_address;
		rd_nwr = 0;
		din = transaction_msg;
		sda_drive = 1'b1;
		transaction_start = 0;
		transaction_bytes_num = num_bytes;
		#CLK_PERIOD transaction_start = 1;
		#CLK_PERIOD transaction_start = 0;
		//@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	

		// start of address byte
		repeat(8) @(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));
		@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	// ack bit 
		sda_drive = 1'b0;	// ack
		repeat(num_bytes) begin 
			@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));
			sda_drive = 1;	// idle
			repeat(8) @(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	// go to ack
			sda_drive = 0; // ack
		end
		@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));
		sda_drive = 1;
		@(posedge transaction_done);
	end
endtask

task i2c_read;
	input logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] num_bytes;
	input logic [6:0] device_address;
	input logic [7:0] expected_read_msg[0:MAX_BYTES_PER_TRANSACTION-1];
	begin
		rd_nwr = 1;
		transaction_bytes_num = num_bytes;
		#(CLK_PERIOD) transaction_start = 1;
		#(CLK_PERIOD) transaction_start = 0;
		@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	
		
		// start of address byte
		repeat(8) @(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// ack bit 
		sda_drive = 1'b0;	// ack

		for (int i = 0; i < num_bytes; i++) begin
			for (int j = 0; j < 8; j++) begin
				@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	// slave device sends bytes on sda
				sda_drive = expected_read_msg[i][7-j];	
			end
			@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));	// go to ack
			sda_drive = 0; // ack
		end
		@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW_CYCLES/2));
		sda_drive = 1;
		@(posedge transaction_done);
	end
endtask


// 100 KHz clock
initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		#CLK_PERIOD reset = 0;

		i2c_write(.num_bytes(3),.device_address(7'h48),.transaction_msg({8'h01, 8'h42,8'hA3}));
		i2c_write(.num_bytes(1),.device_address(7'h48),.transaction_msg({8'h96,08'd0,8'd0}));
		i2c_read(.num_bytes(2),.device_address(7'h48),.expected_read_msg({8'hA0,8'h29,8'd0}));

		$finish;
	end
endmodule