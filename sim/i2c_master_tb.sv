module i2c_master_tb ();
// Parameters
	time CLK_PERIOD = 8ns;
	localparam LOW_CYCLES          = 672;
	localparam LOW        = 336;
	localparam HIGH_CYCLES         = 577;
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


	assign scl_pin = ~scl_wr_en ? 1'b1 : 1'bz;	// should be driven high if nothing is controlling scl
	assign sda_pin = ~sda_wr_en ? sda_drive : 1'bz;	// modify this in tb based on what we expect, i.e. ack, nack, or data bits
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
		// test a 2-byte write 8'b address, 1'b ack, 8'b write, 1'b ack, 8'b write, 1'b ack
		mode = 2'b11;
		slave_addr = 7'b1100101;
		din = {8'b1011_0111,8'b1111_0100};
		sda_drive = 1'b1;	// modify based on expected 
		start = 0;
		#CLK_PERIOD reset = 0;
		#CLK_PERIOD start = 1;
		#CLK_PERIOD start = 0;
		@(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW));	
		repeat(8) begin
		 @(posedge clk iff (i_i2c_master.clock_cycle_counter == LOW));	// advance address bit
		 $display("Matched at time %t: %d", $time, i_i2c_master.clock_cycle_counter);
		end
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// ack bit 
		sda_drive = 1'bx;	// ack

		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// idle
		repeat(8) @(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// go to ack

		sda_drive = 0; // ack

		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1; //idle
		repeat(8) @(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// go to ack
		sda_drive = 0;

		@(posedge done);
		sda_drive = 1; 

		// test 1-byte write
		mode = 2'b01;
		#(CLK_PERIOD) start = 1;
		#(CLK_PERIOD) start = 0;
		repeat(8) @(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// advance address bit
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// ack bit 
		sda_drive = 0;	// ack

		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// idle
		repeat(8) @(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// go to ack
		
		sda_drive = 0; // ack
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;
		@(posedge done);

		// test 2-byte read 
		mode = 2'b00;
		#(CLK_PERIOD) start = 1;
		#(CLK_PERIOD) start = 0;
		repeat(8) @(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// advance address bit
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// ack bit 
		sda_drive = 0;	// ack

		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// read byte 1 0xD9 = 8'b1101_1001
		sda_drive = 1;	// bit 7
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 6
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 0;	// bit 5
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 4
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 3
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 0;	// bit 2
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 0;	// bit 1
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 0
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// master sends ack

		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// read byte 1 0x7A = 8'b0111_1010
		sda_drive = 0;	// bit 7
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 6
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 5
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 4
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 3
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 0;	// bit 2
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 1;	// bit 1
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);
		sda_drive = 0;	// bit 0
		@(i_i2c_master.clock_cycle_counter == LOW_CYCLES/2);	// master sends ack

		@(posedge done);
		sda_drive = 1; 

		$finish;
	end
endmodule