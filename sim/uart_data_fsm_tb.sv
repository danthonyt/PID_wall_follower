module uart_data_fsm_tb ();
	// Parameters
	time        CLK_PERIOD    = 8ns;
	logic       clk                ;
	logic       reset              ;
	logic       fsm_en             ;
	logic       uart_tx_done       ;
	logic       uart_start_tx      ;
	logic [7:0] uart_tx_din        ;
	logic [96:0] fifo_rd_data       ;
	logic       fifo_empty         ;
	logic       fifo_rd_en         ;

	typedef enum logic [3:0] {STATE_IDLE,STATE_READ_FIFO,STATE_UART_SEND_WORD,STATE_UART_WAIT_WORD,STATE_UART_SEND_COMMA,STATE_UART_WAIT_COMMA,STATE_UART_SEND_CR,STATE_UART_WAIT_CR,STATE_UART_SEND_LF,STATE_UART_WAIT_LF} states_t;

	uart_data_fsm #(.FIFO_RD_DATA_WIDTH (96)) i_uart_data_fsm (
			.clk          (clk          ),
			.reset        (reset        ),
			.fsm_en       (fsm_en       ),
			.uart_tx_done (uart_tx_done ),
			.uart_start_tx(uart_start_tx),
			.uart_tx_din  (uart_tx_din  ),
			.fifo_rd_data (fifo_rd_data ),
			.fifo_empty   (fifo_empty   ),
			.fifo_rd_en   (fifo_rd_en   )
		);

		initial begin
			clk = 0;
			forever begin
				#(CLK_PERIOD/2)  clk = ~ clk ;
			end
		end

		initial begin
			reset = 1;
			fsm_en = 0;
			fifo_rd_data = 0;
			fifo_empty = 0;
			uart_tx_done = 0;
			#(CLK_PERIOD);
			reset = 0;
			fsm_en = 1;
			fifo_rd_data = 96'hABCD0032839748AC8DFE3210;
			fifo_empty = 0;
			repeat(8) begin // send first word
				wait(i_uart_data_fsm.state == STATE_UART_WAIT_WORD);
				uart_tx_done = 1;
				#(CLK_PERIOD*2);
				uart_tx_done = 0;
			end
			// send comma
			wait(i_uart_data_fsm.state == STATE_UART_SEND_COMMA);
			uart_tx_done = 1;
			#(CLK_PERIOD*2);
			uart_tx_done = 0;
			repeat(8) begin // send second  word
				wait(i_uart_data_fsm.state == STATE_UART_WAIT_WORD);
				uart_tx_done = 1;
				#(CLK_PERIOD*2);
				uart_tx_done = 0;
			end
			// send comma
			wait(i_uart_data_fsm.state == STATE_UART_SEND_COMMA);
			uart_tx_done = 1;
			#(CLK_PERIOD*2);
			uart_tx_done = 0;
			// send third  word
			repeat(8) begin // send second  word
				wait(i_uart_data_fsm.state == STATE_UART_WAIT_WORD);
				uart_tx_done = 1;
				#(CLK_PERIOD*2);
				uart_tx_done = 0;
			end
			// send newline
			wait(i_uart_data_fsm.state == STATE_UART_WAIT_CR);
			uart_tx_done = 1;
			#(CLK_PERIOD*2);
			uart_tx_done = 0;
			wait(i_uart_data_fsm.state == STATE_UART_WAIT_LF);
			uart_tx_done = 1;
			#(CLK_PERIOD*2);
			uart_tx_done = 0;
			wait(i_uart_data_fsm.state == STATE_IDLE);
			//
			wait(i_uart_data_fsm.state == STATE_UART_WAIT_WORD);
			uart_tx_done = 1;
			#(CLK_PERIOD*2);
			uart_tx_done = 0;
			fifo_empty = 1;
			#(CLK_PERIOD*10);
			fifo_empty = 0;
			fsm_en = 0;
			#(CLK_PERIOD*10);
			fifo_empty = 0;
			fsm_en = 1;
			#(CLK_PERIOD*10);


			$finish;

		end

		endmodule