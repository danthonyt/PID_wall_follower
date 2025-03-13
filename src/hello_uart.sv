module hello_uart (
	input  logic clk      ,
	input  logic reset    ,
	input  logic serial_rx,
	output logic serial_tx
);

	logic           reset ;
	logic           start ;
	logic [(8-1):0] din_tx;

	logic [(8-1):0] dout_rx;
	logic           done   ;

	typedef enum logic [3:0] {STATE_READY,STATE_H,STATE_E,STATE_L1,STATE_L2,STATE_O} states_t;
	states_t state, next_state;

	logic [7:0] data_array [0:4]; // 'HELLO'
	assign data_array = {
		8'h48,
		8'h45,
		8'h4C,
		8'h4C,
		8'h4F
	};
	uart_top #(.DATA_WIDTH(8), .CLKS_PER_BIT(1231)) i_uart_top (
		.reset    (reset    ),
		.start    (start    ),
		.serial_rx(serial_rx),
		.din_tx   (din_tx   ),
		.dout_rx  (dout_rx  ),
		.serial_tx(serial_tx),
		.done     (done     )
	);

	always_ff @(posedge clk or posedge reset) begin : proc_
		if(reset) begin
			<= 0;
		end else begin
			<= ;
		end
	end


endmodule