module top (
	input  logic        clk_in               ,
	input  logic        reset_in             ,
	// measured to determine the actual RPM of the motors
	input  logic        tachometer_pulse_l_in  , 
	input  logic        tachometer_pulse_r_in  , 
	// determines the setpoint of the PID controller
	input  logic [15:0] right_ir             ,
	input  logic [15:0] left_ir              ,
	input  logic        forward_ir           ,
	// disables or enables the robot movement
	input  logic        enable_switch        ,
	// nsleep signal - high enables motor, low disables
	output logic        left_motor_en        ,
	output logic        right_motor_en       ,
	// 0 = forward , 1 = backward
	output logic        left_motor_direction ,
	output logic        right_motor_direction,
	// drives the motors. controls the RPM
	output logic        pwm_l_out            ,
	output logic        pwm_r_out
);
// dc motor has time constant = 100ms
// pwm should be 100 Hz frequency
logic [25:0] rpm_setpoint_l, rpm_setpoint_r;
logic [25:0] rpm_actual_l,rpm_actual_r;
logic [15:0] duty_cycle_l, duty_cycle_r;
logic [25:0] meas_rpm_l_out, meas_rpm_r_out;


tachometer_interface i_tachometer_interface_l (
	.clk_in             (clk_in             ),
	.reset_in           (reset_in           ),
	.tachometer_pulse_in(tachometer_pulse_l_in),
	.actual_rpm_out     (meas_rpm_l_out     )
);
tachometer_interface i_tachometer_interface_r (
	.clk_in             (clk_in             ),
	.reset_in           (reset_in           ),
	.tachometer_pulse_in(tachometer_pulse_r_in),
	.actual_rpm_out     (meas_rpm_r_out     )
);

	logic [10:0] duty;
	logic [31:0] dvsr;
	logic pwm_out;
	// divisor of 18 is approx 100 hz with R = 16
pwm #(.R=16) i_pwm_l (.clk(clk_in), .reset(reset_in), .duty(duty_cycle_l), .dvsr(d'18), .pwm_out(pwm_l_out));
pwm #(.R=16) i_pwm_l (.clk(clk_in), .reset(reset_in), .duty(duty_cycle_r), .dvsr(d'18), .pwm_out(pwm_r_out));


	logic [15:0] k_p;
	logic [15:0] k_i;
	logic [15:0] k_d;
	logic [25:0] set_point_input;
	logic [25:0] meas_process_variable_input;
	logic [OUTPUT_SIZE-1:0] controller_output;
pid_controller #(.PARAM_WIDTH(16), .SETPOINT_WIDTH(26)) i_pid_controller (
	.clk                        (clk_in                     ),
	.reset                      (reset_in                   ),
	.k_p                        (k_p                        ),
	.k_i                        (k_i                        ),
	.k_d                        (k_d                        ),
	.set_point_input            (set_point_input            ),
	.meas_process_variable_input(meas_process_variable_input),
	.controller_output          (controller_output          )
);




endmodule