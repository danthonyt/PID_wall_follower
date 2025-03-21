module ff #(
	parameter D_WIDTH     = 1,
	parameter RESET_VALUE = 0
) (
	input  logic               clk   ,
	input  logic               clk_en,
	input  logic               clr_n ,
	input  logic               reset ,
	input  logic [D_WIDTH-1:0] d     ,
	output logic [D_WIDTH-1:0] q
);
	always_ff @(posedge clk or posedge reset) begin
		if (reset)
			q <= RESET_VALUE;
		else if (~clr_n)
			q <= RESET_VALUE;
		else if (clk_en)
			q <= d;
	end
endmodule