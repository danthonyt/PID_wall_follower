module i2c_test (
	input  logic clk    ,
	input  logic reset  ,
	inout  logic scl_pin,
	inout  logic sda_pin,
	output logic led1   ,
	output logic led2   ,
	output logic led3   ,
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
	logic [           15:0] adc_data   [0:9]               ;
	logic [3:0] adc_idx;

	logic [26:0] delay_counter;
	logic        delay_en     ;
	logic        error        ;
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
		.error                (error                )
	);


	ila_1 ila_1_i (
	.clk(clk), // input wire clk


	.probe0(adc_data[0]), // input wire [15:0]  probe0  
	.probe1(adc_data[1]), // input wire [15:0]  probe1 
	.probe2(adc_data[2]), // input wire [15:0]  probe2 
	.probe3(adc_data[3]), // input wire [15:0]  probe3 
	.probe4(adc_data[4]), // input wire [15:0]  probe4 
	.probe5(adc_data[5]), // input wire [15:0]  probe5 
	.probe6(adc_data[6]), // input wire [15:0]  probe6 
	.probe7(adc_data[7]), // input wire [15:0]  probe7 
	.probe8(adc_data[8]), // input wire [15:0]  probe8 
	.probe9(adc_data[9]), // input wire [15:0]  probe9 
	.probe10(error), // input wire [0:0]  probe10 
	.probe11(transaction_done) // input wire [0:0]  probe11
);


	assign slave_addr = 7'h48;
	typedef enum logic [3:0] {STATE_CONFIGURE,STATE_SET,STATE_SAMPLE,STATE_WAIT,STATE_4MS_WAIT} states_t;
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
			adc_data <= {0,0,0,0,0,0,0,0,0,0};
			state    <= STATE_CONFIGURE;
			adc_idx <= 0;
		end else begin
			transaction_start <= 0;
			delay_en          <= 0;
			unique case (state)
				STATE_CONFIGURE : begin
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'h42,8'h43};
					transaction_bytes_num <= 3;
					state                 <= STATE_4MS_WAIT;
					next_state            <= STATE_SET;
				end
				STATE_SET : begin
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};
					transaction_bytes_num <= 1;
					state                 <= STATE_4MS_WAIT;
					next_state            <= STATE_SAMPLE;

				end
				STATE_SAMPLE : begin
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_4MS_WAIT;
					next_state            <= STATE_SAMPLE;
				end
				STATE_4MS_WAIT : begin
					delay_en <= 1;

					if (transaction_done) begin 
						adc_data[adc_idx] <= {dout[0],dout[1]};
						adc_idx <= adc_idx + 1;
					end
					if(delay_counter == 500000) begin 	// sample every 1 second
						state <= next_state;

					end
				end
			endcase
		end
	end
	assign led4 = error;


	always_comb begin
		led1 = 0;
		led2 = 0;
		led3 = 0;
		//if (adc_data > 49152) led3 = 1;
		//else if (adc_data > 32768) led2 = 1;
		//else led1 = 1;
	end

endmodule 