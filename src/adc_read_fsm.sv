module adc_read_fsm (
	input  logic        clk        ,
	input  logic        reset      ,
	inout  logic        scl_pin    ,
	inout  logic        sda_pin    ,
	output logic [15:0] distance_cm
);
	logic                   transaction_start         ;
	logic                   rd_nwr                    ;
	logic [            6:0] slave_addr                ;
	logic [            7:0] din                  [0:2];
	logic [$clog2(3+1)-1:0] transaction_bytes_num     ;
	logic [            7:0] dout                 [0:2];
	logic                   transaction_done          ;
	logic [           15:0] adc_data                  ;

	longint unsigned delay_counter;
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

	assign slave_addr = 7'h48;	// slave address of adc
	typedef enum logic [3:0] {STATE_CONFIGURE,STATE_SET,STATE_SAMPLE,STATE_50MS_WAIT} states_t;
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
		end else begin
			transaction_start <= 0;
			delay_en          <= 0;
			unique case (state)
				STATE_CONFIGURE : begin // modify adc config register
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h01, 8'h42,8'43};	// select config register, FSR = 4.096v, 32 SPS
					transaction_bytes_num <= 3;
					state                 <= STATE_50MS_WAIT;
					next_state            <= STATE_SET;
				end
				STATE_SET : begin // switch to adc data register
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 0;
					din                   <= {8'h00,8'd0,8'd0};	// select data register to then read conversions
					transaction_bytes_num <= 1;
					state                 <= STATE_50MS_WAIT;
					next_state            <= STATE_SAMPLE;

				end
				STATE_SAMPLE : begin  // read adc data register
					delay_en              <= 0;
					transaction_start     <= 1;
					rd_nwr                <= 1;
					transaction_bytes_num <= 2;
					state                 <= STATE_50MS_WAIT;
					next_state            <= STATE_SAMPLE;
				end
				STATE_50MS_WAIT : begin  // wait for 50 ms and also register data once collected from a transaction
					delay_en <= 1;
					if (transaction_done)
						adc_data <= {dout[0],dout[1]};
					if(delay_counter == 6250000000000)    // sample every 50 ms
						state <= next_state;

				end
			endcase
		end
	end

	logic [15:0] distance_cm_adc_value[0:70];

	initial begin
		$readmemh("adc_lookup.mem", distance_cm_adc_value);  // Load HEX file into array
	end

	always_comb begin
		distance_cm = 10;
		for (int i = 0; i < 71; i++) begin
			if (adc_data > distance_cm_adc_value[i]) begin	// distance is found by comparing to expected values for each distance
				distance_cm = i + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
endmodule 