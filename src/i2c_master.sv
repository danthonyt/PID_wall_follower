module i2c_master (
	input  logic        clk       ,
	input  logic        reset     ,
	input  logic        start     , // initiates a transaction
	input  logic [ 1:0] mode      , // 00 = read 2 bytes, 01 = write 1 byte, 11 = write 2 bytes
	inout  wire         scl_pin   , // SCL line
	inout  wire         sda_pin   , // SDA line
	input  logic [ 6:0] slave_addr, // address of slave device
	input  logic [ 7:0] din [0:1] ,
	output logic [15:0] dout      , // i2c read data if read selected
	output logic        done        // transaction complete
);

	logic [ 6:0] slave_addr_reg          ; // address of slave device
	logic [ 1:0] mode_reg                ;
	logic        scl_out                 ;
	wire         scl_in                  ;
	logic        sda_out                 ;
	wire         sda_in                  ;
	logic        scl_wr_en               ;
	logic        sda_wr_en               ;
	logic [10:0] clock_cycle_counter, delay_counter;
	logic [ 3:0] bit_count               ;
	logic [ 7:0] din_reg            [0:1];
	logic [15:0] dout_reg                ;
	logic        delay_en                ;
	typedef enum logic [3:0] {STATE_IDLE,STATE_START,STATE_ADDRESS,STATE_CHECK_ACK,STATE_SEND_ACK,STATE_SCL_DELAY,STATE_NACK,STATE_WRITE_1,STATE_WRITE_2,STATE_READ_1,STATE_READ_2,STATE_NEXT_BIT_DELAY, STATE_STOP_SCL, STATE_STOP_SDA} states_t;
	states_t state, next_state;

// in order to read data from ads1115
// write 1 byte, then read 2 bytes
// in order to configure
// write 3 bytes
	localparam LOW_CYCLES          = 673;
	localparam HIGH_CYCLES         = 577;
	localparam MINIMUM_HOLD_CYCLES = 75 ;
	assign scl_pin = scl_wr_en ? scl_out : 1'bz; // to drive scl
	assign sda_pin = sda_wr_en ? sda_out : 1'bz; // to drive sda
	assign scl_in  = scl_pin ;	// to read from scl
	assign sda_in  = sda_pin ; // to read from sda

	// scl clock generator 100 KHz also counts clock cycles
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			scl_out             <= 1'bz;
			clock_cycle_counter <= 0;
		end else begin
			if (scl_wr_en) begin	// the master is in control of the clock
				clock_cycle_counter <= clock_cycle_counter + 1;
				if(clock_cycle_counter <= LOW_CYCLES) begin	// low scl
					scl_out <= 0;
				end else if ( clock_cycle_counter < HIGH_CYCLES+LOW_CYCLES)begin	// high scl
					scl_out <= 1'bz;
				end else begin
					scl_out             <= 0;
					clock_cycle_counter <= 1;
				end
			end

		end
	end

	// delay counter
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			delay_counter <= 0;
		end else begin
			if (delay_en)
				delay_counter <= delay_counter + 1;
			else
				delay_counter <= 0;
		end
	end


	// current state logic
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			mode_reg            <= mode;
			slave_addr_reg      <= slave_addr;
			din_reg             <= din;
			done                <= 0;
			scl_wr_en           <= 0;
			scl_out             <= 1'bz;
			sda_wr_en           <= 0;
			sda_out             <= 1'bz;
			clock_cycle_counter <= 0;
			bit_count           <= 0;
			state               <= STATE_IDLE;
			next_state          <= STATE_IDLE;
			dout_reg            <= 0;
		end else begin
			unique case (state)
				STATE_IDLE : begin
					done                <= 0;
					scl_wr_en           <= 0;
					scl_out             <= 1'bz;
					sda_wr_en           <= 0;
					sda_out             <= 1'bz;
					clock_cycle_counter <= 0;
					bit_count           <= 0;
					state               <= STATE_IDLE;
					next_state          <= STATE_IDLE;
					dout_reg            <= 0;
					if (start) begin
						state          <= STATE_START;	// begin attempt of read or write
						mode_reg       <= mode;
						slave_addr_reg <= slave_addr;
						din_reg        <= din;
					end else begin
						state <= STATE_IDLE;
					end
				end
				STATE_START : begin	// Pull SDA Low, wait 600ns, then enable SCL generation	 control sda and then scl when exiting
					sda_wr_en <= 1;
					scl_wr_en <= 0;
					sda_out   <= 0;
					delay_en  <= 1;
					if (delay_counter == MINIMUM_HOLD_CYCLES) begin	// enable scl after min hold time
						state     <= STATE_ADDRESS;
						scl_wr_en <= 1;
						delay_en  <= 0;
					end
				end
				STATE_ADDRESS : begin	// send 8 bits of slave address frame {7'b address, 1'b r/nwr} control scl and sda control sda and scl
					sda_wr_en <= 1;
					scl_wr_en <= 1;
					if (clock_cycle_counter == 10) begin	// change sda only during low scl
						bit_count <= bit_count + 1;
						if (bit_count < 7) begin
							sda_out <= slave_addr_reg[6 - bit_count] ? 1'bz : 1'b0;
						end else if (bit_count == 7) begin
							sda_out <= ~mode_reg[0]? 1'bz : 1'b0;
						end else begin
							bit_count  <= 0;
							next_state <= mode_reg[0] ? STATE_WRITE_1 : STATE_READ_1;	// write or read transaction
							state      <= STATE_CHECK_ACK;
						end
					end
				end
				STATE_CHECK_ACK : begin	// check ack bit of address frame release control of sda line
					sda_wr_en <= 0;
					if (clock_cycle_counter >= LOW_CYCLES + HIGH_CYCLES/2) begin	// sample in the middle of high scl
						if (sda_in == 1'b0)	// low sda is an ack from the slave
							state <= STATE_NEXT_BIT_DELAY;
						else
							state <= STATE_NACK;
					end
				end
				STATE_NACK : begin
					state <= STATE_NACK;
				end
				STATE_WRITE_1 : begin
					sda_wr_en <= 1;
					scl_wr_en <= 1;
					if (clock_cycle_counter == 10) begin	// change sda only during low scl
						bit_count <= bit_count + 1;
						if (bit_count <= 7) begin
							sda_out <= din_reg[0][7 - bit_count] ? 1'bz : 1'b0;
						end else begin
							bit_count  <= 0;
							next_state <= mode_reg[1] ? STATE_WRITE_2 : STATE_STOP_SCL;	// write or read transaction
							state      <= STATE_CHECK_ACK;
						end
					end
				end
				STATE_WRITE_2 : begin
					sda_wr_en <= 1;
					scl_wr_en <= 1;
					if (clock_cycle_counter == 10) begin	// change sda only during low scl
						bit_count <= bit_count + 1;
						if (bit_count <= 7) begin
							sda_out <= din_reg[1][7 - bit_count]? 1'bz : 1'b0;
						end else begin
							bit_count  <= 0;
							next_state <= STATE_STOP_SCL;	// write or read transaction
							state      <= STATE_CHECK_ACK;
						end
					end
				end
				STATE_READ_1 : begin 	// read from slave device - release sda line
					sda_wr_en <= 0;
					if (clock_cycle_counter >= LOW_CYCLES + HIGH_CYCLES/2) begin	// sample in the middle of high scl
						bit_count <= bit_count + 1;
						dout_reg  <= { dout_reg[14:0], sda_in };	// shift in sda line bits MSB first
						if (bit_count == 7) begin
							state      <= STATE_SEND_ACK;
							next_state <= STATE_READ_2;
						end
					end
				end
				STATE_READ_2 : begin
					sda_wr_en <= 0;
					if (clock_cycle_counter >= LOW_CYCLES + HIGH_CYCLES/2) begin	// sample in the middle of high scl
						bit_count <= bit_count + 1;
						dout_reg  <= { dout_reg[14:0], sda_in };	// shift in sda line bits MSB first
						if (bit_count == 7) begin
							state      <= STATE_SEND_ACK;
							next_state <= STATE_STOP_SCL;
						end
					end
				end
				STATE_SEND_ACK : begin
					sda_wr_en <= 1;
					if (clock_cycle_counter == 10) begin
						sda_out <= 1'b0;	// pull down SDA to acknowledge
						state   <= STATE_NEXT_BIT_DELAY;
					end
				end
				STATE_NEXT_BIT_DELAY : begin	// move on to the next bit after sampling the previous
					if (clock_cycle_counter <= 5) state <= next_state;
				end
				STATE_STOP_SCL : begin
					if (clock_cycle_counter >= LOW_CYCLES) begin	// scl should be high
						scl_wr_en <= 0;	// release scl line while scl is already high
						delay_en  <= 1;
						state <= STATE_STOP_SDA;
					end

				end
				STATE_STOP_SDA : begin
					if (delay_counter >= MINIMUM_HOLD_CYCLES) begin
						done      <= 1;	// release sda line
						sda_wr_en <= 0;
						dout <= dout_reg;
						state     <= STATE_IDLE;
					end
				end
			endcase
		end
	end
endmodule