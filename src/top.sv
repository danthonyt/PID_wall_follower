module top (
	input  logic clk               ,
	input  logic reset             ,
	// i2c interface
	inout  logic scl_pin           ,
	inout  logic sda_pin           ,
	// tachometer inputs
	input  logic tachometer_out_b_l, // use to measure pwm of left/right motor
	input  logic tachometer_out_b_r,
	// motor inputs/outputs
	input  logic motor_en_sw       , // switch input for motor enable
	output logic motor_en          , // enables both motors when high
	output logic motor_pwm_l       , // pwm drives left/right motor
	output logic motor_pwm_r
);
// dc motor has time constant = 100ms
// pwm should be 100 Hz frequency
	logic [25:0] rpm_setpoint_l, rpm_setpoint_r;
	logic [25:0] rpm_actual_l,rpm_actual_r;
	logic [15:0] duty_cycle_l, duty_cycle_r;
	logic [25:0] meas_rpm_l, meas_rpm_r;


	tachometer_interface i_tachometer_interface_l (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.tachometer_pulse_in(tachometer_out_b_l),
		.actual_rpm_out     (meas_rpm_l        )
	);
	tachometer_interface i_tachometer_interface_r (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.tachometer_pulse_in(tachometer_out_b_r),
		.actual_rpm_out     (meas_rpm_r        )
	);

	logic [10:0] duty   ;
	logic [31:0] dvsr   ;
	logic        pwm_out;

	pwm #(.R=16) i_pwm_l (.clk(clk_in), .reset(reset), .duty(duty_cycle_l), .dvsr(d'18), .pwm_out(motor_pwm_l));
	pwm #(.R=16) i_pwm_r (.clk(clk_in), .reset(reset), .duty(duty_cycle_r), .dvsr(d'18), .pwm_out(motor_pwm_r));







endmodule