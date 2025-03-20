module motor_control #(
	parameter RPM_RESOLUTION = 16,
	parameter PWM_RESOLUTION = 16,
	parameter MAX_RPM_OFFSET = 50
	)(
	input logic clk,   
	input logic clk_en_tach, 
	input logic clk_en_adc,
	input logic reset, 
	input logic signed [PWM_RESOLUTION:0] duty_cycle_offset_l,
	input logic signed [PWM_RESOLUTION:0] duty_cycle_offset_r,
	input logic [RPM_RESOLUTION-1:0] base_rpm,
	input logic signed [RPM_RESOLUTION:0] rpm_offset,
	output logic [PWM_RESOLUTION-1:0] duty_cycle_l,
	output logic [PWM_RESOLUTION-1:0] duty_cycle_r,
	output logic [RPM_RESOLUTION-1:0] rpm_setpoint_l,
	output logic [RPM_RESOLUTION-1:0] rpm_setpoint_r

	
);
localparam DUTY_CYCLE_LIMIT   = ((2**PWM_RESOLUTION-1)*3)/4; // limit Duty cycle to 75% of the maximum

	logic signed [RPM_RESOLUTION:0] base_rpm_signed;
	logic signed [PWM_RESOLUTION:0] next_duty_cycle_l_signed;
	logic signed [PWM_RESOLUTION:0] next_duty_cycle_r_signed;
	logic [PWM_RESOLUTION-1:0] next_duty_cycle_l_unsigned;
	logic [PWM_RESOLUTION-1:0] next_duty_cycle_r_unsigned;
	logic signed [RPM_RESOLUTION:0] next_rpm_setpoint_l_signed;
	logic signed [RPM_RESOLUTION:0] next_rpm_setpoint_r_signed;
	logic [RPM_RESOLUTION-1:0] next_rpm_setpoint_l_unsigned;
	logic [RPM_RESOLUTION-1:0] next_rpm_setpoint_r_unsigned;
	logic signed [RPM_RESOLUTION:0] rpm_offset_adjusted;

	assign next_duty_cycle_l_signed = $signed({1'd0,duty_cycle_l}) + duty_cycle_offset_l;
	assign next_duty_cycle_r_signed = $signed({1'd0,duty_cycle_r}) + duty_cycle_offset_r;
	// limit duty cycle if too high, or set to zero if negative.
	assign next_duty_cycle_l_unsigned = (next_duty_cycle_l_signed >= DUTY_CYCLE_LIMIT ? DUTY_CYCLE_LIMIT
		:( next_duty_cycle_l_signed[PWM_RESOLUTION] ? 0 : next_duty_cycle_l_signed[PWM_RESOLUTION-1:0]));
	assign next_duty_cycle_r_unsigned = (next_duty_cycle_r_signed >= DUTY_CYCLE_LIMIT ? DUTY_CYCLE_LIMIT
		:( next_duty_cycle_r_signed[PWM_RESOLUTION] ? 0 : next_duty_cycle_r_signed[PWM_RESOLUTION-1:0]));

	assign base_rpm_signed = {1'd0,base_rpm};

	// limit rpm offset to 30% of the base rpm for our purposes we will use 45 RPM
	assign rpm_offset_adjusted = (rpm_offset > MAX_RPM_OFFSET ) ? MAX_RPM_OFFSET : (rpm_offset < -MAX_RPM_OFFSET ? -MAX_RPM_OFFSET : rpm_offset); 
	assign next_rpm_setpoint_l_signed = base_rpm_signed - rpm_offset_adjusted; // set a default rpm (100 rpm) and the pid output is the value that is added to left wheel
	assign next_rpm_setpoint_r_signed = base_rpm_signed + rpm_offset_adjusted; // and subtracted from right wheel
	assign next_rpm_setpoint_l_unsigned = next_rpm_setpoint_l_signed[RPM_RESOLUTION-1:0];
	assign next_rpm_setpoint_r_unsigned = next_rpm_setpoint_r_signed[RPM_RESOLUTION-1:0];



	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			duty_cycle_l <= 0;
			duty_cycle_r <= 0;
		end else begin
			if(clk_en_tach) begin
				duty_cycle_l <= next_duty_cycle_l_unsigned ;
				duty_cycle_r <= next_duty_cycle_r_unsigned ;

			end
		end
	end

	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			rpm_setpoint_r <= 0;
			rpm_setpoint_l <= 0;
		end else begin
			if(clk_en_adc) begin
				rpm_setpoint_r <= next_rpm_setpoint_r_unsigned;
				rpm_setpoint_l <= next_rpm_setpoint_l_unsigned;

			end
		end
	end

endmodule