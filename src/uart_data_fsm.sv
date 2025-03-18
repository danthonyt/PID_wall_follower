module uart_data_fsm #(parameter FIFO_RD_DATA_WIDTH=8) (
	input  logic                          clk          ,
	input  logic                          reset        ,
	input  logic                          fsm_en       ,
	// UART
	input  logic                          uart_tx_done ,
	output logic                          uart_start_tx,
	output logic [                   7:0] uart_tx_din  ,
	// fifo
	input  logic [FIFO_RD_DATA_WIDTH-1:0] fifo_rd_data ,
	input  logic                          fifo_empty   ,
	output logic                          fifo_rd_en
);
	localparam HEX_DIGITS          = FIFO_RD_DATA_WIDTH/4;
	localparam HEX_DIGITS_PER_WORD = 8                   ;
	typedef enum logic [3:0] {STATE_IDLE,STATE_READ_FIFO,STATE_UART_SEND_WORD,STATE_UART_WAIT_WORD,STATE_UART_SEND_COMMA,STATE_UART_WAIT_COMMA,STATE_UART_SEND_CR,STATE_UART_WAIT_CR,STATE_UART_SEND_LF,STATE_UART_WAIT_LF} states_t;
	states_t state;
	// 8 elements for first, second and third word, 2 element for commas, 2 elements for newline
	//logic [7:0] hex_out_arr[0:(HEX_DIGITS-1)+2*HEX_DIGITS+2+2];
	logic [7:0] hex_out_arr[0:HEX_DIGITS-1];	// each hex digit is 4 bits
	logic   [FIFO_RD_DATA_WIDTH-1:0] fifo_rd_data_reg;
	integer                          hex_out_arr_idx ;
	genvar i;
	generate
		for (i = 0; i < HEX_DIGITS; i++) begin
			ascii_bin_to_hex i_ascii_bin_to_hex_w1 (.binary_in(fifo_rd_data_reg[FIFO_RD_DATA_WIDTH-1-4*i:FIFO_RD_DATA_WIDTH-4-4*i]), .hex_out(hex_out_arr[i]));
		end
	endgenerate

	// take one half word from fifo, send 2 bytes over uart, repeat until fifo is empty
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			state            <= STATE_IDLE;
			// data
			hex_out_arr_idx  <= 0;
			// uart
			uart_start_tx    <= 0;
			uart_tx_din      <= 0;
			// fifo
			fifo_rd_en       <= 0;
			fifo_rd_data_reg <= 0;

		end else begin
			if (fsm_en) begin
				unique case (state)
					STATE_IDLE : begin
						hex_out_arr_idx  <= 0;
						uart_start_tx    <= 0;
						uart_tx_din      <= 0;
						fifo_rd_en       <= 0;
						fifo_rd_data_reg <= 0;
						if(!fifo_empty)begin
							fifo_rd_en <= 1;
							state      <= STATE_READ_FIFO;
						end
					end
					STATE_READ_FIFO : begin
						state            <= STATE_UART_SEND_WORD;
						hex_out_arr_idx  <= 0;
						uart_start_tx    <= 0;
						uart_tx_din      <= 0;
						fifo_rd_en       <= 0;
						fifo_rd_data_reg <= fifo_rd_data;
					end
					STATE_UART_SEND_WORD : begin
						state         <= STATE_UART_WAIT_WORD;
						uart_start_tx <= 1;
						uart_tx_din   <= hex_out_arr[hex_out_arr_idx];
					end
					STATE_UART_WAIT_WORD : begin
						uart_start_tx <= 0;
						if (uart_tx_done) begin
							if (hex_out_arr_idx >= (HEX_DIGITS-1)) begin // begin newline send after sending all words
								hex_out_arr_idx <= 0;
								state           <= STATE_UART_SEND_CR;
							end else begin
								hex_out_arr_idx <= hex_out_arr_idx + 1;
								if ((hex_out_arr_idx % HEX_DIGITS_PER_WORD == 7) && (hex_out_arr_idx != 0)) begin // send comma after sending a full word and not done
									state <= STATE_UART_SEND_COMMA;
								end else begin
									state <= STATE_UART_SEND_WORD;// continue sending if not done with word
								end
							end
						end
					end
					STATE_UART_SEND_COMMA : begin
						state         <= STATE_UART_WAIT_COMMA;
						uart_start_tx <= 1;
						uart_tx_din   <= 8'h2C;	// comma
					end
					STATE_UART_WAIT_COMMA : begin
						uart_start_tx <= 0;
						if (uart_tx_done) begin
							state <= STATE_UART_SEND_WORD;
						end
					end
					STATE_UART_SEND_CR : begin
						state         <= STATE_UART_WAIT_CR;
						uart_start_tx <= 1;
						uart_tx_din   <= 8'h0D;	// carriage return
					end
					STATE_UART_WAIT_CR : begin
						uart_start_tx <= 0;
						if (uart_tx_done) begin
							state <= STATE_UART_SEND_LF;
						end
					end
					STATE_UART_SEND_LF : begin
						state         <= STATE_UART_WAIT_LF;
						uart_start_tx <= 1;
						uart_tx_din   <= 8'h0A;	// line feed
					end
					STATE_UART_WAIT_LF : begin
						uart_start_tx <= 0;
						if (uart_tx_done) begin
							state <= STATE_IDLE;
						end
					end

				endcase

			end else begin
				state            <= STATE_IDLE;
				// data
				hex_out_arr_idx  <= 0;
				// uart
				uart_start_tx    <= 0;
				uart_tx_din      <= 0;
				// fifo
				fifo_rd_en       <= 0;
				fifo_rd_data_reg <= 0;
			end
		end
	end
endmodule