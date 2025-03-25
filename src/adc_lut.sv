module adc_lut (
	input logic clk,
	input logic reset,
	input logic signed [15:0] side_adc_data,
	input logic signed [15:0] diag_adc_data,
	output logic [6:0] side_distance,
	output logic [6:0] diag_distance
);
	logic  [15:0] adc_to_side_distance_arr[0:70];
	logic [15:0] adc_to_diag_distance_arr[0:70];
	initial begin
		$readmemh("adc_lookup_side.mem", adc_to_side_distance_arr);  // Load HEX file into array
		$readmemh("adc_lookup_diag.mem", adc_to_diag_distance_arr);  // Load HEX file into array
	end

	always_comb begin
		side_distance = 10;
		for (int i = 71; i > 0; i--) begin
			if ($signed({side_adc_data[15],side_adc_data}) < $signed({1'b0,adc_to_side_distance_arr[i-1]})) begin	// distance is found by comparing to expected values for each distance
				side_distance = (i-1) + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
	always_comb begin
		diag_distance = 10;
		for (int i = 71; i > 0; i--) begin
			if ($signed({diag_adc_data[15],diag_adc_data}) < $signed({1'b0,adc_to_diag_distance_arr[i-1]})) begin	// distance is found by comparing to expected values for each distance
				diag_distance = (i-1) + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
endmodule