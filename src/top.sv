module top (
	input  logic clk               ,
	input  logic reset             ,
	// i2c interface
	//inout  logic scl_pin           ,
	//inout  logic sda_pin           ,
	// uart interface
	output logic serial_tx         , // sends PID error data
	input  logic uart_en_sw        , // enables uart communication
	input  logic dtr               , // low when pc is ready for communication
	// tachometer inputs
	input  logic tachometer_out_b_l, // use to measure pwm of left/right motor
	input  logic tachometer_out_b_r,
	// motor inputs/outputs
	input  logic motor_en_sw       , // switch input for motor enable
	output logic motor_en_l        , // enables both motors when high
	output logic motor_en_r        ,
	output logic motor_pwm_l       , // pwm drives left/right motor
	output logic motor_pwm_r
);
// dc motor has time constant = 100ms
// pwm should be 100 Hz frequency

	logic [15:0] duty_cycle_l;
	pwm #(.R(16)) i_pwm_l (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_l),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_l )
	);

	logic [15:0] duty_cycle_r;
	pwm #(.R(16)) i_pwm_r (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_r),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_r )
	);
	assign motor_en_l = motor_en_sw;
	assign motor_en_r = motor_en_sw;

	logic [8:0] rpm_l_measured;
	logic [8:0] rpm_r_measured;
	tachometer_interface i_tachometer_interface_l (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.tachometer_pulse_in(tachometer_out_b_l),
		.actual_rpm_out     (rpm_l_measured    )
	);
	tachometer_interface i_tachometer_interface_r (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.tachometer_pulse_in(tachometer_out_b_r),
		.actual_rpm_out     (rpm_r_measured    )
	);

	logic [ 8:0] rpm_l_setpoint         ;
	logic [ 8:0] rpm_l_measured         ;
	logic [15:0] duty_cycle_l_correction;
	pid_controller #(.PID_INT_WIDTH(8), .PID_FRAC_WIDTH(8), .SP_WIDTH(8), .PID_OUT_WIDTH(16)) i_pid_controller_tach_l (
		.clk               (clk                    ),
		.reset             (reset                  ),
		.k_p               (16'h0080               ),
		.k_i               (0                      ),
		.k_d               (0                      ),
		.setpoint          (rpm_l_setpoint         ),
		.feedback          (rpm_l_measured         ),
		.control_signal_out(duty_cycle_l_correction)
	);

	logic [ 8:0] rpm_r_setpoint         ;
	logic [ 8:0] rpm_r_measured         ;
	logic [15:0] duty_cycle_r_correction;
	pid_controller #(.PID_INT_WIDTH(8), .PID_FRAC_WIDTH(8), .SP_WIDTH(8), .PID_OUT_WIDTH(16)) i_pid_controller_tach_r (
		.clk               (clk                    ),
		.reset             (reset                  ),
		.k_p               (16'h0080               ),
		.k_i               (0                      ),
		.k_d               (0                      ),
		.setpoint          (rpm_r_setpoint         ),
		.feedback          (rpm_r_measured         ),
		.control_signal_out(duty_cycle_r_correction)
	);
	assign rpm_r_setpoint = 100;
	assign rpm_l_setpoint = 100;


	always_ff @(posedge clk or posedge reset) begin : proc_
		if(reset) begin
			duty_cycle_l <= 0;
			duty_cycle_r <= 0;
		end else begin
			duty_cycle_l <= duty_cycle_l + duty_cycle_l_correction;
			duty_cycle_r <= duty_cycle_r + duty_cycle_r_correction;
		end
	end





	/*

	adc_read_fsm i_adc_read_fsm (
	.clk        (clk                 ),
	.reset      (reset               ),
	.scl_pin    (scl_pin             ),
	.sda_pin    (sda_pin             ),
	.distance_cm(distance_cm_measured)
	);

	logic [  7:-8] k_p                 ;
	logic [  7:-8] k_i                 ;
	logic [  7:-8] k_d                 ;
	logic [  15:0] distance_cm_setpoint;
	logic [  15:0] distance_cm_measured;
	logic [19+8:0] rpm_diff      ;
	assign distance_cm_setpoint = d'20;	// distance to wall should be 20 cm
	// set a default rpm (100 rpm) and the pid output is the value that is added to left wheel
	// and subtracted from right wheel
	assign rpm_l_setpoint = 100 + rpm_diff;
	assign rpm_r_setpoint = 100 - rpm_diff;
	pid_controller #(.PID_INT_WIDTH(8), .PID_FRAC_WIDTH(8), .SP_WIDTH(16)) i_pid_controller_ir (
	.clk           (clk                 ),
	.reset         (reset               ),
	.k_p           (k_p                 ),
	.k_i           (k_i                 ),
	.k_d           (k_d                 ),
	.setpoint      (distance_cm_setpoint),
	.feedback      (distance_cm_measured),
	.control_signal(rpm_diff      )
	);
	*/

	logic       start_tx    ;
	logic [7:0] tx_msg      ;
	logic       uart_tx_done;
	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk         ),
		.reset    (reset       ),
		.start    (start_tx    ),
		.din      (tx_msg      ),
		.serial_tx(serial_tx   ),
		.done     (uart_tx_done)
	);



endmodule