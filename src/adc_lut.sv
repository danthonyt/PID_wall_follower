module adc_lut (
	input logic clk,
	input logic reset,
	input logic [15:0] adc_data,
	output logic [6:0] distance_cm_out
);
	logic [6:0] distance_cm;
	logic [15:0] distance_cm_adc_value[0:70];
	initial begin
		$readmemh("adc_lookup.mem", distance_cm_adc_value);  // Load HEX file into array
	end

	always_comb begin
		distance_cm = 10;
		for (int i = 0; i < 71; i++) begin
			if (adc_data > distance_cm_adc_value[i]) begin	// distance is found by comparing to expected values for each distance
				distance_cm = i + 10;	// 10 cm has the highest voltage output and decreases as distance increases
				break;
			end;
		end
	end
	always_ff @(posedge clk or posedge reset) begin 
		if(reset) begin
			 distance_cm_out <= 0;
		end else begin
			 distance_cm_out <= distance_cm;
		end
	end
endmodule