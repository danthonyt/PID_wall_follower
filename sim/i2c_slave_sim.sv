module i2c_slave_sim (
	input logic       clk       ,
	input logic       reset     ,
	inout logic       scl       ,
	inout logic       sda       ,
	input logic [6:0] slave_addr,
	output logic done
);
	logic [15:0] conversion_reg;
	logic [15:0] config_reg    ;
	logic [ 7:0] active_reg    ;
	logic        sda_out       ;
	logic        sda_wr_en     ;
	logic        is_active     ;
	logic        rd_nwr_op     ;
	logic [ 7:0] sda_byte      ;
	logic [ 3:0] bit_cnt       ;
typedef enum logic [3:0] {STATE_IDLE,STATE_ACK,STATE_ADDRESS,STATE_WRITE,STATE_READ} states_t;
	states_t state, next_state;
	assign sda = sda_wr_en ? sda_out : 1'bz;
	always_ff @(posedge scl or posedge rst) begin
		if(reset) begin
			config_reg     <= 0;
			conversion_reg <= 0;
			sda_wr_en      <= 0;
		end else begin
			unique case (state)
				STATE_IDLE:
				STATE_ACK:
				STATE_WRITE:
				STATE_READ:
			
				default : /* default */;
			endcase
			if (is_active && rd_nwr_op) begin	// master read
				if (bit_cnt == )
				end else if (is_active && ~rd_nwr_op) begin	// master write
					if (bit_cnt == )
					end else begin
						if (bit_cnt == 8 && sda_byte[7:1] == slave_addr) begin
							is_active = 1;
							rd_nwr_op = sda_byte[0] ? 1 : 0;
							bit_cnt   <= 0;
						end
			end
		end
	end


	always_ff @(negedge scl or posedge rst) begin : proc_
		if(rst) begin
			sda_out <= 1;
			bit_cnt <= 0;
		end else begin
			unique case (state)
				STATE_IDLE: begin 

				end
				STATE_ACK: begin 
				end
				STATE_ADDRESS: begin 
					if (bit_cnt < 8) begin	// address
						sda_byte <= {sda_byte, sda};
					end else if (sda_byte[7:1] == slave_addr) begin
						is_active = 1;
						rd_nwr_op = sda_byte[0] ? 1 : 0;
						bit_cnt   <= 0;
					end
				end
				STATE_WRITE: begin 
				end
				STATE_READ: begin 
					if (bit_cnt < 8) begin 	// first byte
						unique case (active_reg)
							8'h00 : begin
								sda_out <= conversion_reg[15-bit_cnt];
							end
							8'h01 : begin
								sda_out <= config_reg[15-bit_cnt];
							end
						endcase
					end else if (bit_cnt == 8) begin // ack bit
						sda_out <= 0;
					end else if (bit_cnt < 17) begin // second byte
						unique case (active_reg)
							8'h00 : begin
								sda_out <= conversion_reg[7-bit_cnt + 9];
							end
							8'h01 : begin
								sda_out <= config_reg[7-bit_cnt + 9];
							end
						endcase
					end else if (bit_cnt == 17) begin // ack bit
						sda_out <= 0;
					end
				end
			endcase
		end
		endmodule