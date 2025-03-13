module uart_data_fsm (
	input  logic clk      ,
	input  logic reset    ,
	input  logic dtr      ,
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


	typedef enum logic [3:0] {STATE_READY,STATE_SEND_BYTE,STATE_WAIT} states_t;
	states_t state;

	logic [7:0] data_array[0:5]; // 'HELLO\n'
	assign data_array = {
		8'h48,
		8'h45,
		8'h4C,
		8'h4C,
		8'h4F,
		8'h0D
	};

	int index;
	always_ff @(posedge clk or posedge reset) begin : proc_
		if(reset) begin
			state <= STATE_READY;
			start_tx <= 0;
			tx_msg <= 0;
		end else begin
			if (fsm_en) begin
				unique case (state)
					STATE_READY : begin
						state <= STATE_SEND_BYTE;
					end
					STATE_SEND_BYTE : begin
						tx_msg <= data_array[index];
						if(!dtr) begin
							start_tx <= 1;
							state <= STATE_WAIT;
							index <= index >= 5 ? 0 : index + 1;
						end
					end
					STATE_WAIT    : begin
						start_tx <= 0;
						if (uart_tx_done) begin
							state <= STATE_SEND_BYTE;
						end
					end
				endcase
			end
			else begin
				state <= STATE_READY;
				start_tx <= 0;
				tx_msg <= 0;
			end
		end
	end


endmodule