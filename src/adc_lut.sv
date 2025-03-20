module adc_lut (
	input logic clk,
	input logic reset,
	input logic signed [15:0] raw_adc_data,
	output logic [6:0] distance_cm_out
);
	logic [6:0] raw_distance_cm,adjusted_distance_cm_trunc;
	logic [6:-8] adjusted_distance_cm,raw_distance_cm_fp;
	logic [15:0] lut_distance_cm_threshold_arr[0:70];
	initial begin
		$readmemh("adc_lookup.mem", lut_distance_cm_threshold_arr);  // Load HEX file into array
	end

	always_comb begin
		raw_distance_cm = 10;
		for (int i = 0; i < 71; i++) begin
			if (raw_adc_data > lut_distance_cm_threshold_arr[i]) begin	// distance is found by comparing to expected values for each distance
				raw_distance_cm = i + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
	always_ff @(posedge clk or posedge reset) begin 
		if(reset) begin
			 distance_cm_out <= 0;
		end else begin
			 distance_cm_out <= adjusted_distance_cm_trunc;
		end
	end

	assign raw_distance_cm_fp = {raw_distance_cm,8'd0};
	// convert to distance to side of robot
	assign adjusted_distance_cm = (raw_distance_cm_fp>>1) + (raw_distance_cm_fp>>3) + (raw_distance_cm_fp>>4) + (raw_distance_cm_fp>>6) +(raw_distance_cm_fp>>8);// cos(45)*x = 0.707*x = x*(1/2+1/8+1/16+1/64)
												// = x>>1 + x>>3 + x>>4 + x>>6 +x>>8    0.707 ~ .10110101
	assign adjusted_distance_cm_trunc = adjusted_distance_cm[6:0];
endmodule