module uart_data_fsm (
	input  logic clk      ,
	input  logic reset    ,
	input  logic fsm_en   ,
	output logic serial_tx
);
	logic       start_tx    ;
	logic [7:0] tx_msg      ;
	logic       uart_tx_done;
	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk         ),
		.reset    (reset       ),
		.start    (start_tx    ),
		.din      (tx_msg      ),
		.serial_tx(serial_tx   ),
		.done     (uart_tx_done)
	);


	typedef enum logic [3:0] {STATE_RESET,STATE_START_BYTE_SEND,STATE_WAIT_BYTE_SEND,STATE_1S_DELAY} states_t;
	states_t state;

	logic [7:0] data_array[0:6]; // 'HELLO\n'
	assign data_array = {
		8'h48,
		8'h45,
		8'h4C,
		8'h4C,
		8'h4F,
		8'h0A,
		8'h0D
	};


	logic counter_en;
	logic count_done;
	int unsigned count_lim;
	int unsigned count;
counter i_counter (.clk(clk), .rst(reset), .en(counter_en), .count_lim(count_lim), .count(count), .done(count_done));


	int index;
	always_ff @(posedge clk or posedge reset) begin : proc_
		if(reset) begin
			state <= STATE_RESET;
			start_tx <= 0;
			tx_msg <= 0;
			index <= 0;
			counter_en <= 0;
			count_lim <= 0;
		end else begin
			if (fsm_en) begin
				unique case (state)
					STATE_RESET : begin
						start_tx <= 0;
						tx_msg <= 0;
						index <= 0;
						state <= STATE_START_BYTE_SEND;
					end
					STATE_START_BYTE_SEND : begin
						tx_msg <= data_array[index];
						start_tx <= 1;
						state <= STATE_WAIT_BYTE_SEND;
					end
					STATE_WAIT_BYTE_SEND    : begin
						start_tx <= 0;
						if (uart_tx_done) begin
							if (index >= 6) begin 
								counter_en <= 1;
								count_lim <= 125000000;
								index <= 0;
								state <= STATE_1S_DELAY;
							end else begin 
								index <= index + 1;
								state <= STATE_START_BYTE_SEND;
							end 
						end
					end
					STATE_1S_DELAY: begin
						if (count_done) begin
							counter_en <= 0;
							state <= STATE_RESET;
						end
					end
				endcase
			end
			else begin
				state <= STATE_RESET;
				start_tx <= 0;
				tx_msg <= 0;
				index <= 0;
			end
		end
	end


endmodule