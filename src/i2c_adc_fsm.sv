module i2c_adc_fsm (
	input  logic               clk                     ,
	input  logic               reset                   ,
	inout  logic               scl_pin                 ,
	inout  logic               sda_pin                 ,
	output logic signed [15:0] adc_data_diag_sensor    ,
	output logic signed [15:0] adc_data_side_sensor    ,
	output logic signed [15:0] adc_data_diag_sensor_avg,
	output logic signed [15:0] adc_data_side_sensor_avg
);
	logic                   transaction_start         ;
	logic                   rd_nwr                    ;
	logic [            6:0] slave_addr                ;
	logic [            7:0] din                  [0:2];
	logic [$clog2(3+1)-1:0] transaction_bytes_num     ;
	logic [            7:0] dout                 [0:2];
	logic [            7:0] dout_reg             [0:2];
	logic                   transaction_done          ;

	int   unsigned        delay_counter;
	logic                 delay_en     ;
	logic                 error        ;
	logic signed   [19:0] side_sum,diag_sum;
	logic signed   [19:0] side_avg_long,diag_avg_long;
	int                   side_idx,diag_idx;
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
	typedef enum logic [4:0] {STATE_CONFIG0,STATE_WAIT_CONFIG0,STATE_SET0,STATE_WAIT_SET0,STATE_CLEAR0,STATE_WAIT_CLEAR0,STATE_READ0,STATE_WAIT_READ0,STATE_16MS_WAIT0
		,STATE_CONFIG1,STATE_WAIT_CONFIG1,STATE_SET1,STATE_WAIT_SET1,STATE_CLEAR1,STATE_WAIT_CLEAR1,STATE_READ1,STATE_WAIT_READ1,STATE_16MS_WAIT1} states_t;
	states_t state;


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
			delay_en             <= 0;
			adc_data_side_sensor <= 0;
			adc_data_diag_sensor <= 0;
			state                <= STATE_CONFIG0;
			side_idx             <= 0;
			diag_idx             <= 0;
			side_sum             <= 0;
			diag_sum             <= 0;
			side_avg_long        <= 0;
			diag_avg_long        <= 0;
		end else begin
			transaction_start <= 0;
			delay_en          <= 0;
			unique case (state)
				STATE_CONFIG0 : begin	// conifgure ADC config register for side sensor
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'hC3,8'h63}; // 64 sps, select AIN0 (side sensor), single shot mode
					transaction_bytes_num <= 3;
					state                 <= STATE_WAIT_CONFIG0;
				end
				STATE_WAIT_CONFIG0 : begin
					if (transaction_done) begin
						state <= STATE_SET0;
					end
				end
				STATE_SET0 : begin	// select ADC data register
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};
					transaction_bytes_num <= 1;
					state                 <= STATE_WAIT_SET0;
				end
				STATE_WAIT_SET0 : begin
					if (transaction_done) begin
						state <= STATE_16MS_WAIT0;
					end
				end
				STATE_16MS_WAIT0 : begin
					delay_en <= 1;
					if(delay_counter >= 1950000-1) begin 	// wait 16 ms for read data
						state <= STATE_CLEAR0;
					end
				end
				STATE_CLEAR0 : begin	// clear ADC sample data
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_WAIT_CLEAR0;
				end
				STATE_WAIT_CLEAR0 : begin
					if (transaction_done) begin
						state                <= STATE_READ0;
					end
				end

				STATE_READ0 : begin	// READ ADC sample data
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_WAIT_READ0;
				end
				STATE_WAIT_READ0 : begin	// READ ADC sample data
					if (transaction_done) begin
						adc_data_side_sensor <= {dout[0],dout[1]};
						state                <= STATE_CONFIG1;

						if (side_idx < 16) begin
							side_idx      <= side_idx + 1;
							side_avg_long <= side_sum + {dout[0],dout[1]};
						end else begin
							side_idx      <= 0;
							side_avg_long <= (side_sum >>> 4);
							side_sum      <= 0;
						end
					end
				end

				STATE_CONFIG1 : begin	// conifgure ADC config register for side sensor
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'hD3,8'h63}; // 64 sps, select AIN1 (diagonal sensor), single shot mode
					transaction_bytes_num <= 3;
					state                 <= STATE_WAIT_CONFIG1;
				end
				STATE_WAIT_CONFIG1 : begin
					if (transaction_done) begin
						state <= STATE_SET1;
					end
				end
				STATE_SET1 : begin	// select ADC data register
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};
					transaction_bytes_num <= 1;
					state                 <= STATE_WAIT_SET1;
				end
				STATE_WAIT_SET1 : begin
					if (transaction_done) begin
						state <= STATE_16MS_WAIT1;
					end
				end
				STATE_16MS_WAIT1 : begin
					delay_en <= 1;
					if(delay_counter >= 1950000-1) begin 	// wait 16 ms for read data
						state <= STATE_CLEAR1;
					end
				end
				STATE_CLEAR1 : begin	// clear ADC sample data
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_WAIT_CLEAR1;
				end
				STATE_WAIT_CLEAR1 : begin
					if (transaction_done) begin
						state                <= STATE_READ1;
					end
				end
				STATE_READ1 : begin	// READ ADC sample data
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_WAIT_READ1;
				end
				STATE_WAIT_READ1 : begin	// READ ADC sample data
					if (transaction_done) begin
						adc_data_diag_sensor <= {dout[0],dout[1]};
						state                <= STATE_CONFIG0;
						// average ir sensor samples for mapping to distances
						if (diag_idx < 16) begin
							diag_idx <= diag_idx + 1;
							diag_sum <= diag_sum + {dout[0],dout[1]};
						end else begin
							diag_idx      <= 0;
							diag_avg_long <= (diag_sum >>> 4);
							diag_sum      <= 0;
						end
					end
				end
			endcase

		end
	end
	assign adc_data_side_sensor_avg = side_avg_long[15:0];
	assign adc_data_diag_sensor_avg = diag_avg_long[15:0];
endmodule 