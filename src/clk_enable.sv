module clk_enable #(
	parameter DIVISOR     = 1
) (
	input  logic clk_in  ,
	input  logic reset_in,
	output logic clk_en
);

	logic [$clog2(DIVISOR+1)-1:0] counter;
	always_ff @(posedge clk_in or posedge reset_in) begin
		if(reset_in) begin
			clk_en  <= 0;
			counter <= 0;
		end else begin
			if (counter == DIVISOR) begin
				counter <= 0;
				clk_en  <= 1;
			end
			else begin
				clk_en  <= 0;
				counter <= counter + 1;
			end
		end
	end
endmodule : clk_enable