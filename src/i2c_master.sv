module i2c_master (
	input  logic        clk            ,
	input  logic        reset          ,
	input  logic        start_wr       , // initiates a write
	input  logic        start_rd       , // initiates a read
	inout  logic        scl_pin        , // SCL line
	inout  logic        sda_pin        , // SDA line
	input  logic [ 6:0] peripheral_addr, // address of slave device
	input  logic [ 7:0] addr_ptr       , // address of register to access
	output logic [15:0] dout           , // i2c read data if read selected
	output logic        done_wr        , // write complete
	output logic        done_rd          // read complete
);

	logic [6:0] peripheral_addr_reg; // address of slave device
	logic [7:0] addr_ptr_reg       ; // address pointer register
	logic       start_wr_reg       ;
	logic       start_rd_reg       ;
	logic       scl_wr_data        ;
	logic       scl_pin            ;
	logic       scl_in             ;
	logic       sda_pin            ;
	logic       sda_wr_data        ;
	logic       sda_in             ;
	logic       scl_wr_en          ;
	logic       sda_wr_en          ;
	logic [6:0] cycle_count        ;
	typedef enum logic [3:0] {IDLE,START_SDA_LOW,ADDRESS_FRAME,DATA_FRAME,STOP_SCL_HIGH,S_H_DELAY,STOP_SDA_HIGH} states_t;
	states_t state, next_state;

	localparam LOW_CYCLES       = 673 ;
	localparam S_H_DELAY_CYCLES = 75  ;
	localparam DIVISOR          = 1249; // 100 KHz scl
	assign scl_pin = scl_wr_en ? scl_wr_data : 1'bz; // to drive scl
	assign sda_pin = sda_wr_en ? sda_wr_data : 1'bz; // to drive sda
	assign scl_in  = sda_pin ;	// to read from scl
	assign sda_in  = scl_pin ; // to read from sda

	// register inputs used in fsm
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			peripheral_addr_reg <= 0;
			addr_ptr_reg        <= 0;
		end else begin
			peripheral_addr_reg <= peripheral_addr;
			addr_ptr_reg        <= addr_ptr;
			start_wr_reg        <= start_wr;
			start_rd_reg        <= start_rd;
		end
	end

	// current state logic
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			done_wr <= 0;
			done_rd <= 0;
			scl_wr_en <= 0;
			scl_wr_data <= 1'bz;
			sda_wr_en <= 0;
			sda_wr_data <= 1'bz;
			cycle_count <= 0;
			state <<= IDLE;
		end else begin
			done_wr <= 0;
			done_rd <= 0;
			scl_wr_en <= 0;
			scl_wr_data <= 1'bz;
			sda_wr_en <= 0;
			sda_wr_data <= 1'bz;
			unique case (state)
				IDLE: begin
					cycle_count <= 0;
					if (start_wr || start_rd) state <= START_SDA_LOW;	// begin attempt of read or write
					else state <= IDLE;
				end
				START_SDA_LOW: begin	// Pull SDA Low for start
					sda_wr_en <= 1;
					sda_wr_data <= 0;
					state <= S_H_DELAY;
				end
				S_H_DELAY: begin	// 600ns Delay to ensure hold time
					sda_wr_en <= 1;
					sda_wr_data <= 0;
					if(cycle_count == S_H_DELAY_CYCLES) begin
						state <= START_SCL_LOW;
						cycle_count <= 0;
					end else begin
						state <= S_H_DELAY;
						cycle_count <= cycle_count + 1;
					end
					ADDRESS_FRAME: begin // Pull SCL low
						scl_wr_en <= 1;
						scl_wr_data <=

						end
						endmodule