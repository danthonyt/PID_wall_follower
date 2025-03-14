module counter (
	input logic clk,
	input logic rst,
	input logic en,
	input int unsigned count_lim,	// number of cycles to count until restarting the count
	output int unsigned count,		// current count
	output logic done								// triggers when count resets to zero after reaching the count limit
);

// delay counter
	always_ff @(posedge clk or posedge rst) begin
		if(rst) begin
			done <= 0;
			count <= 0;
		end else begin
			done <= 0;
			count <= 0;
			if (en) begin
				count <= count + 1;
				if (count == count_lim-1) begin 
					count <= 0;
					done <= 1;
				end
			end
		end
	end

endmodule