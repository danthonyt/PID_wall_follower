module debounce (
	input  logic clk   , // Clock
	input  logic reset ,
	input  logic pb_in ,
	output logic pb_out
);
	int   clock_count;
	logic pulse_sent ;
	always_ff @(posedge clk or posedge reset) begin
			if(reset) begin
				clock_count <= 0;
				pulse_sent  <= 0;
				pb_out <= 0;
			end else begin
				clock_count <= 0;
				pb_out <= 0;
				if(~pulse_sent) begin
					if (pb_in)
						clock_count <= clock_count + 1;
					if(clock_count >= 3750000) begin	// send pulse if button is high for 30 ms
						pb_out     <= 1;
						pulse_sent <= 1;
					end
				end else if (~pb_in) begin
					pulse_sent <= 0;
				end

			end
		end

endmodule