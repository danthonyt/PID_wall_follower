module adc_lut (
	input logic clk,
	input logic reset,
	input logic signed [15:0] adc_data_diag,
	output logic [6:0] distance_diag
);
	logic [15:0] adc_to_diag_distance_arr[0:70];
	initial begin
		$readmemh("adc_lookup_diag.mem", adc_to_diag_distance_arr);  // Load HEX file into array
	end
	always_comb begin
		distance_diag = 10;
		for (int i = 71; i > 0; i--) begin
			if ($signed({adc_data_diag[15],adc_data_diag}) < $signed({1'b0,adc_to_diag_distance_arr[i-1]})) begin	// distance is found by comparing to expected values for each distance
				distance_diag = (i-1) + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
endmodule