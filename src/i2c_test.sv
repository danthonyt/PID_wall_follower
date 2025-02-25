module i2c_test (
	input  logic       clk    ,
	input  logic       reset  ,
	inout  logic       scl_pin,
	inout  logic       sda_pin,

	output logic led1,
	output logic led2,
	output logic led3,
	output logic led4
);
	logic                   transaction_start         ;
	logic                   rd_nwr                    ;
	logic [            6:0] slave_addr                ;
	logic [            7:0] din                  [0:2];
	logic [$clog2(3+1)-1:0] transaction_bytes_num     ;
	logic [            7:0] dout                 [0:2];
	logic [            7:0] dout_reg             [0:2];
	logic                   transaction_done          ;

	logic [26:0] delay_counter;
	logic        delay_en     ;
	logic error;
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
		.transaction_done     (transaction_done     ),
		.error                (error)
	);

	ila_0 i_ila (
	.clk(clk), // input wire clk


	.probe0(led1), // input wire [0:0]  probe0  
	.probe1(led2), // input wire [0:0]  probe1 
	.probe2(led3), // input wire [0:0]  probe2 
	.probe3(error), // input wire [0:0]  probe3 
	.probe4(transaction_done) // input wire [0:0]  probe4
);



	assign slave_addr = 7'h48;
	typedef enum logic [3:0] {STATE_CONFIGURE,STATE_SET,STATE_SAMPLE,STATE_WAIT,STATE_1SECOND_WAIT} states_t;
	states_t state,next_state;

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


	always_ff @(posedge clk or posedge reset) begin 
		if(reset) begin
			dout_reg <= {0,0,0};
			led1 <= 0;
			led2 <= 0;
			led3 <= 0;
			//led4 <= 0;
			state <= STATE_CONFIGURE;
		end else begin
			transaction_start <= 0;
			delay_en          <= 0;
			unique case (state)
				STATE_CONFIGURE : begin
					delay_en <= 0;
					led1 <=1;
					led2 <= 0;
					led3 <= 0;
					//led4 <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'h85,8'h83};
					//din                   <= {8'h01, 8'h42,8'hA3};
					transaction_bytes_num <= 3;
					state                 <= STATE_1SECOND_WAIT;
					next_state            <= STATE_SET;
				end
				STATE_SET : begin
					delay_en <= 0;
					led1 <= 0;
					led2 <= 1;
					led3 <= 0;
					//led4 <= 0;

					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'h85,8'h83};
					//din                   <= {8'h00, 0,0};
					transaction_bytes_num <= 1;
					state                 <= STATE_1SECOND_WAIT;
					next_state            <= STATE_SAMPLE;
					/*
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};
					transaction_bytes_num <= 1;
					state                 <= STATE_1SECOND_WAIT;
					next_state            <= STATE_SAMPLE;
					*/
				end
				STATE_SAMPLE : begin
					delay_en <= 0;
					led1 <= 0;
					led2 <= 0;
					led3 <= 1;
					//led4 <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_1SECOND_WAIT;
					next_state            <= STATE_SAMPLE;
				end
				STATE_1SECOND_WAIT : begin
					delay_en <= 1;

					if (transaction_done) dout_reg <= dout;
					if(delay_counter == 125000000) begin 	// sample every 1 second
						state <= next_state;

					end
				end
			endcase
		end
	end
assign led4 = error;
/*
	always_comb begin 
		 if ({dout_reg[0],dout_reg[1]} > 32768) led1 = 1;
		else led1 = 0;
	end
	*/
	/*
	always_comb begin 
		if ({dout_reg[0],dout_reg[1]} > 49152) led = 3'h4;
		else if ({dout_reg[0],dout_reg[1]} > 32768) led = 3'h2;
		else if ({dout_reg[0],dout_reg[1]} > 16384) led = 3'h1;
		else led = 3'h1;
	end
	*/
endmodule 