module adc_read_fsm #(parameter MAX_BYTES_PER_TRANSACTION=3) (
	input  logic                                           clk                                                              ,
	input  logic                                           reset                                                            ,
	input  logic                                           i2c_transaction_done                                             ,
	input  logic [                                    7:0] i2c_master_dout                [0:MAX_BYTES_PER_TRANSACTION-1]   ,
	output logic                                           i2c_transaction_start                                            ,
	output logic                                           i2c_transaction_rd_nwr                                           ,
	output logic [                                    6:0] i2c_transaction_slave_addr                                       ,
	output logic [                                    7:0] i2c_master_din                    [0:MAX_BYTES_PER_TRANSACTION-1],
	output logic [$clog2(MAX_BYTES_PER_TRANSACTION+1)-1:0] i2c_transaction_bytes_num                                        ,
	output logic [15:0] adc_data,
	output logic [                                    6:0] distance_cm
);
	//logic [15:0] adc_data;

	logic          delay_en        ;
	int   unsigned delay_count,delay_count_lim;
	logic          delay_count_done;
	counter i_counter (
		.clk      (clk             ),
		.rst      (reset           ),
		.en       (delay_en        ),
		.count_lim(delay_count_lim ),
		.count    (delay_count     ),
		.done     (delay_count_done)
	);
	adc_lut i_adc_lut (.clk(clk),.reset(reset),.adc_data(adc_data), .distance_cm_out(distance_cm));

	assign i2c_transaction_slave_addr = 7'h48;	// slave address of adc
	assign delay_count_lim            = 6250000;
	typedef enum logic [3:0] {STATE_RESET,STATE_I2C_MODIFY_CONFIG,STATE_I2C_SELECT_DATA_REG,STATE_I2C_READ_ADC,STATE_I2C_TRANSACTION_WAIT,STATE_50MS_DELAY} states_t;
	states_t state,next_state;
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			adc_data                  <= 0;
			i2c_transaction_start     <= 0;
			i2c_transaction_rd_nwr    <= 0;
			i2c_master_din            <= {8'h00, 8'h00,8'h00};	// select config register, FSR = 4.096v, 32 SPS
			i2c_transaction_bytes_num <= 1;
			state                     <= STATE_RESET;
			next_state                <= STATE_RESET;
		end else begin
			i2c_transaction_start <= 0;
			delay_en              <= 0;
			unique case (state)
				STATE_RESET : begin
					adc_data                  <= 0;
					i2c_transaction_start     <= 0;
					i2c_transaction_rd_nwr    <= 0;
					i2c_master_din            <= {8'h00, 8'h00,8'h00};	
					i2c_transaction_bytes_num <= 1;
					state                <= STATE_I2C_MODIFY_CONFIG;
				end
				STATE_I2C_MODIFY_CONFIG : begin // send write to modify adc config register
					i2c_transaction_start     <= 1;
					i2c_transaction_rd_nwr    <= 0;
					i2c_master_din            <= {8'h01, 8'h42,8'h43};	// select config register, FSR = 4.096v, 32 SPS
					i2c_transaction_bytes_num <= 3;
					next_state                <= STATE_I2C_SELECT_DATA_REG;
					state                     <= STATE_I2C_TRANSACTION_WAIT;
				end
				STATE_I2C_SELECT_DATA_REG : begin // send write to select adc data register as read output
					
					i2c_transaction_start     <= 1;
					i2c_transaction_rd_nwr    <= 0;
					i2c_master_din            <= {8'h10,8'd0,8'd0};//{8'h00,8'd0,8'd0};	// select data register to then read conversions
					i2c_transaction_bytes_num <= 1;
					next_state                <= STATE_I2C_READ_ADC;
					state                     <= STATE_I2C_TRANSACTION_WAIT;

				end
				STATE_I2C_READ_ADC : begin  // send read to get ADC sample output
					i2c_transaction_start     <= 1;
					i2c_transaction_rd_nwr    <= 1;
					i2c_master_din            <= {8'h00,8'd0,8'd0};	// read adc data register
					i2c_transaction_bytes_num <= 2;
					next_state                <= STATE_50MS_DELAY; //STATE_50MS_DELAY;
					state                     <= STATE_I2C_TRANSACTION_WAIT;
				end
				STATE_I2C_TRANSACTION_WAIT : begin
					if (i2c_transaction_done) begin
						adc_data <= {i2c_master_dout[0],i2c_master_dout[1]};
						state    <= next_state;
					end
				end
				STATE_50MS_DELAY : begin  // wait for 50 ms and also register data once collected from a transaction
					delay_en <= 1;
					if(delay_count_done) state <= STATE_I2C_READ_ADC;  // sample every 50 ms
				end
			endcase
		end
	end


endmodule 