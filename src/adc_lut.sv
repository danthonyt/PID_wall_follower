module adc_lut (
	input logic clk,
	input logic reset,
	input logic signed [15:0] raw_adc_data,
	output logic [6:0] raw_distance_cm,
	output logic [6:0] distance_cm_cos45
);
	logic [6:0] raw_distance_cm,adjusted_distance_cm_trunc;
	logic [6:-8] adjusted_distance_cm,raw_distance_cm_fp;
	logic  [15:0] lut_distance_cm_threshold_arr[0:69];
	logic [6:0] next_distance_cm_out;
	initial begin
		$readmemh("adc_lookup.mem", lut_distance_cm_threshold_arr);  // Load HEX file into array
	end

	always_comb begin
		raw_distance_cm = 10;
		for (int i = 70; i > 0; i--) begin
			if ($signed({raw_adc_data[15],raw_adc_data}) < $signed({1'b0,lut_distance_cm_threshold_arr[i-1]})) begin	// distance is found by comparing to expected values for each distance
				raw_distance_cm = i + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
	always_ff @(posedge clk or posedge reset) begin 
		if(reset) begin
			 distance_cm_cos45 <= 0;
		end else begin
			 distance_cm_cos45 <= next_distance_cm_out;
		end
	end
	assign next_distance_cm_out = adjusted_distance_cm_trunc;
	assign raw_distance_cm_fp = {raw_distance_cm,8'd0};
	// convert to distance to side of robot
	assign adjusted_distance_cm = (raw_distance_cm_fp>>1) + (raw_distance_cm_fp>>3) + (raw_distance_cm_fp>>4) + (raw_distance_cm_fp>>6) +(raw_distance_cm_fp>>8);// cos(45)*x = 0.707*x = x*(1/2+1/8+1/16+1/64+1/256)
	assign adjusted_distance_cm_trunc = adjusted_distance_cm[6:0];
endmodule