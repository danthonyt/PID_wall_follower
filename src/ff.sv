module ff #(parameter D_WIDTH=1,
	parameter RESET_VALUE=0)(
	input logic clk,
	input logic rst,
	input logic [D_WIDTH-1:0] d,
	output logic [D_WIDTH-1:0] q
);
	always_ff @(posedge clk or posedge rst) begin
		if (rst) 
			q <= RESET_VALUE;
		else 
			q <= d;
	end
endmodule