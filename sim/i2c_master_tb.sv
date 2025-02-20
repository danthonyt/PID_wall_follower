module i2c_master_tb ();
// Parameters
	time CLK_PERIOD = 8ns;
	logic clk;
	logic reset;
	logic start;
	logic [1:0] mode;
	wire scl_pin;
	wire sda_pin;
	reg sda_drive;
	logic [6:0] slave_addr;
	logic [7:0] din[0:1];
	logic [15:0] dout;
	logic done;
	logic sda_wr_en,scl_wr_en;

	typedef enum logic [3:0] {STATE_IDLE,STATE_START,STATE_ADDRESS,STATE_CHECK_ACK,STATE_SEND_ACK,STATE_SCL_DELAY,STATE_NACK,STATE_WRITE_1,STATE_WRITE_2,STATE_READ_1,STATE_READ_2,STATE_SEND_ACK_DELAY, STATE_STOP_SCL, STATE_STOP_SDA} states_t;


	assign scl_pin = ~scl_wr_en ? 1'b1 : 1'bz;
	assign sda_pin = ~sda_wr_en ? sda_drive : 1'bz;	// assume ack 
	assign sda_wr_en = i_i2c_master.sda_wr_en;
	assign scl_wr_en = i_i2c_master.scl_wr_en;
i2c_master i_i2c_master (
	.clk       (clk       ),
	.reset     (reset     ),
	.start     (start     ),
	.mode      (mode      ),
	.slave_addr(slave_addr),
	.din       (din       ),
	.dout      (dout      ),
	.done      (done      ),
	.scl_pin   (scl_pin   ),
	.sda_pin   (sda_pin   )
);
// 100 KHz clock
initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		// test a write
		mode = 2'b11; // write 2 bytes
		slave_addr = 7'b1100101;
		din = {8'b1011_0111,8'b1111_0100};
		sda_drive = 1'b1;	// modify based on expected 
		start = 0;
		#(CLK_PERIOD*3) reset = 0;
		#(CLK_PERIOD*3) start = 1;
		#(CLK_PERIOD*2) start = 0;;
		@(posedge done);
		reset = 1;
		mode = 2'b01; // write 1 byte
		#(CLK_PERIOD) reset = 0;
		#(CLK_PERIOD) start = 1;
		#(CLK_PERIOD) start = 0;
		@(posedge done);
		$finish;
	end
endmodule