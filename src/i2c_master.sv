module i2c_master #(parameter MAX_BYTES_PER_TRANSACTION=3) (
	input  logic                                           clk                                 ,
	input  logic                                           reset                               ,
	input  logic                                           transaction_start                   , // initiates a transaction
	input  logic                                           rd_nwr                              , // 0 = write, 1 = read
	inout  wire                                            scl_pin                             , // SCL line
	inout  wire                                            sda_pin                             , // SDA line
	input  logic [                                    6:0] slave_addr                          , // address of slave device
	input  logic [                                    7:0] din [0:MAX_BYTES_PER_TRANSACTION-1] ,
	input  logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] transaction_bytes_num               ,
	output logic [                                    7:0] dout [0:MAX_BYTES_PER_TRANSACTION-1], // i2c read data if read selected
	output logic                                           transaction_done                    , // transaction complete
	output logic                                           error
);
// inputs to be registered
	logic [                                    6:0] slave_addr_reg                                          ; // address of slave device
	logic                                           rd_nwr_reg                                              ;
	logic [                                    7:0] din_reg                  [0:MAX_BYTES_PER_TRANSACTION-1];
	logic [                                    7:0] dout_reg                 [0:MAX_BYTES_PER_TRANSACTION-1];
	logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] transaction_bytes_num_reg                               ;
	// counter signals
	int unsigned clock_cycle_counter;
	int unsigned delay_counter      ;
	// fsm outputs
	logic                                           scl_out,scl_out_actual;
	logic                                           sda_out,sda_out_actual;
	logic                                           scl_wr_en                   ;
	logic                                           sda_wr_en                   ;
	logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] current_transaction_byte_num;
	logic [                                    3:0] bit_count                   ;
	logic                                           delay_en                    ;
	// fsm state signals
	typedef enum logic [3:0] {STATE_READY,STATE_START,STATE_ADDRESS,STATE_CHECK_ACK,STATE_SEND_ACK,STATE_NACK,STATE_WRITE,STATE_READ, STATE_STOP} states_t;
	states_t state, next_state;
	// constants
		// 5000 cycles for 50 khz
	//localparam LOW_CYCLES          = 2500;
	//localparam HIGH_CYCLES         = 2500;
	// 2500 cycles for 50 khz
	//localparam LOW_CYCLES          = 1250;
	//localparam HIGH_CYCLES         = 1250;
	//12,500 cycles for 10 khz scl
	//localparam LOW_CYCLES          = 6250;
	//localparam HIGH_CYCLES         = 6250;
	localparam LOW_CYCLES          = 673;
	localparam HIGH_CYCLES         = 577;
	localparam MINIMUM_HOLD_CYCLES = 75 ;

	assign scl_out_actual = scl_out ? 1'bz : 1'b0;
	assign sda_out_actual = sda_out ? 1'bz : 1'b0;
	assign scl_pin        = scl_wr_en ? scl_out_actual : 1'bz; // to drive scl
	assign sda_pin        = sda_wr_en ? sda_out_actual : 1'bz; // to drive sda

	// scl clock generator 100 KHz also counts clock cycles
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			scl_out             <= 1'b1;
			clock_cycle_counter <= 0;
		end else begin
			if (scl_wr_en) begin	// the master is in control of the clock
				clock_cycle_counter <= clock_cycle_counter + 1;
				if(clock_cycle_counter <= LOW_CYCLES) begin	// low scl
					scl_out <= 0;
				end else if ( clock_cycle_counter < HIGH_CYCLES+LOW_CYCLES)begin	// high scl
					scl_out <= 1'b1;
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
			rd_nwr_reg                   <= 0;
			slave_addr_reg               <= 0;
			din_reg                      <= {8'd0,8'd0,8'd0};
			transaction_bytes_num_reg    <= 0;
			dout_reg                     <= {8'd0,8'd0,8'd0};
			dout                         <= {8'd0,8'd0,8'd0};
			transaction_done             <= 0;
			scl_wr_en                    <= 0;
			sda_wr_en                    <= 0;
			sda_out                      <= 1'b1;
			bit_count                    <= 0;
			state                        <= STATE_READY;
			next_state                   <= STATE_READY;
			current_transaction_byte_num <= 0;
			error                        <= 0;
		end else begin
			unique case (state)
				STATE_READY : begin
					rd_nwr_reg                   <= rd_nwr;
					slave_addr_reg               <= slave_addr;
					din_reg                      <= din;
					transaction_bytes_num_reg    <= transaction_bytes_num;
					dout_reg                     <= {8'd0,8'd0,8'd0};
					dout                         <= {8'd0,8'd0,8'd0};
					transaction_done             <= 0;
					scl_wr_en                    <= 0;
					sda_wr_en                    <= 0;
					sda_out                      <= 1'b1;
					bit_count                    <= 0;
					state                        <= STATE_READY;
					next_state                   <= STATE_READY;
					current_transaction_byte_num <= 0;
					//error                        <= 0;
					if (transaction_start)
						state <= STATE_START;	// begin attempt of read or write
				end
				STATE_START : begin	// Pull SDA Low, wait 600ns, then enable SCL generation	 control sda and then scl when exiting
					sda_wr_en <= 1;
					scl_wr_en <= 0;
					sda_out   <= 0;
					delay_en  <= 1;
					if (delay_counter == LOW_CYCLES/2) begin	// enable scl after min hold time
						state     <= STATE_ADDRESS;
						scl_wr_en <= 1;
						delay_en  <= 0;
					end
				end
				STATE_ADDRESS : begin	// send 8 bits of slave address frame {7'b address, 1'b r/nwr} control scl and sda control sda and scl
					sda_wr_en <= 1;
					scl_wr_en <= 1;
					if (clock_cycle_counter == LOW_CYCLES/2) begin	// change sda only during low scl
						bit_count <= bit_count + 1;
						if (bit_count < 7) begin	// bits 1 - 7
							sda_out <= slave_addr_reg[6 - bit_count];
						end else if (bit_count == 7) begin // bit 8
							sda_out <= rd_nwr_reg;
						end else begin
							bit_count  <= 0;
							next_state <= rd_nwr_reg ? STATE_READ : STATE_WRITE;	// write or read transaction
							state      <= STATE_CHECK_ACK;
						end
					end
				end
				STATE_CHECK_ACK : begin	// check ack bit of address frame release control of sda line
					sda_wr_en <= 0;
					if (clock_cycle_counter <= LOW_CYCLES/2) begin	// wait until next low scl
						error <= 0;
						state <= next_state;
					end else if (clock_cycle_counter == LOW_CYCLES + HIGH_CYCLES/2) begin	// sample in the middle of high scl
						if (sda_pin == 1'b1)	// high sda is a nack
							state <= STATE_NACK;
					end
				end
				STATE_NACK : begin
					state <= STATE_STOP;
					error <= 1;
				end
				STATE_WRITE : begin
					sda_wr_en <= 1;
					scl_wr_en <= 1;
					if (clock_cycle_counter == LOW_CYCLES/2) begin	// change sda only during low scl
						bit_count <= bit_count + 1;
						if (bit_count <= 7) begin
							sda_out <= din_reg[current_transaction_byte_num][7 - bit_count];
						end else begin
							current_transaction_byte_num <= current_transaction_byte_num + 1;
							bit_count                    <= 0;
							next_state                   <= (current_transaction_byte_num == transaction_bytes_num-1) ? STATE_STOP : STATE_WRITE;	// write or read transaction
							state                        <= STATE_CHECK_ACK;
						end
					end
				end
				STATE_READ : begin 	// read from slave device - release sda line
					sda_wr_en <= 0;
					if (bit_count == 8) begin
						if (clock_cycle_counter == LOW_CYCLES/2) begin
							state                        <= STATE_SEND_ACK;	// line up to start of next clock
							next_state                   <= (current_transaction_byte_num == transaction_bytes_num-1) ? STATE_STOP: STATE_READ;
							current_transaction_byte_num <= current_transaction_byte_num + 1;
							bit_count                    <= 0;
						end
					end else if (clock_cycle_counter == LOW_CYCLES + HIGH_CYCLES/2) begin	// sample in the middle of high scl
						bit_count                              <= bit_count + 1;
						dout_reg[current_transaction_byte_num] <= { dout_reg[current_transaction_byte_num][6:0], sda_pin };	// shift in sda line bits MSB first
					end

				end
				STATE_SEND_ACK : begin
					sda_wr_en <= 1;
					sda_out   <= 1'b0;	// pull down SDA to acknowledge
					if (clock_cycle_counter == LOW_CYCLES/2) state <= next_state;
				end
				STATE_STOP : begin
					if (delay_counter == 0) begin
						sda_wr_en <= 1;
						sda_out <= 0;
					end else if (delay_counter == LOW_CYCLES) begin // wait for at least 600 ns to allow next start condition
						if(!error) dout             <= dout_reg;
						transaction_done <=  1;
						state <= STATE_READY;
						delay_en <= 0;
					end else if (delay_counter == LOW_CYCLES/2) begin	// wait at least 600 ns after scl is high
						sda_wr_en <= 0;
					end
					if (clock_cycle_counter >= LOW_CYCLES) begin	// scl should be high
						scl_wr_en <= 0;	// release scl line while scl is already high
						delay_en  <= 1;
					end

				end
			endcase
		end
	end
endmodule