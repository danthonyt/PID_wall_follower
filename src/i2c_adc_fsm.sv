module i2c_adc_fsm (
	input  logic clk    ,
	input  logic reset  ,
	inout  logic scl_pin,
	inout  logic sda_pin,
	output logic signed [15:0] adc_data,
	output logic signed [15:0] adc_data_avg
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
	logic        error        ;
	logic signed [19:0] adc_avg_accum;
	logic signed [19:0] adc_data_avg_long;
	int i;
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
	assign slave_addr = 7'h48;
	typedef enum logic [3:0] {STATE_CONFIGURE,STATE_SET,STATE_SAMPLE,STATE_WAIT,STATE_30MS_WAIT} states_t;
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
			adc_data <= 0;
			state    <= STATE_CONFIGURE;
			i <= 0;
			adc_avg_accum <= 0;
			adc_data_avg_long <= 0;
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
					state                 <= STATE_30MS_WAIT;
					next_state            <= STATE_SET;
				end
				STATE_SET : begin
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};
					transaction_bytes_num <= 1;
					state                 <= STATE_30MS_WAIT;
					next_state            <= STATE_SAMPLE;

				end
				STATE_SAMPLE : begin
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_30MS_WAIT;
					next_state            <= STATE_SAMPLE;
				end
				STATE_30MS_WAIT : begin
					delay_en <= 1;

					if (transaction_done) begin 
						adc_data <= {dout[0],dout[1]};
						
						if (i < 16) begin
							i <= i + 1;
							adc_avg_accum <= adc_avg_accum + {dout[0],dout[1]};
						end else begin
							i <= 0;
							adc_data_avg_long <= (adc_avg_accum >>> 4);
							adc_avg_accum <= 0;
						end
					end
					if(delay_counter >= 3910000-1) begin 	// sample every 31.3 ms
						state <= next_state;

					end
				end
			endcase
		end
	end
	assign adc_data_avg = adc_data_avg_long[15:0];
endmodule 