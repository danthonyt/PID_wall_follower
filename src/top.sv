module top (
	input  logic clk               ,
	input  logic reset             ,
	//input logic test_sw,
	// i2c interface
	//inout  logic scl_pin           ,
	//inout  logic sda_pin           ,
	// uart interface
	output logic uart_serial_tx    , // sends PID error data
	input  logic uart_en_sw        , // enables uart communication
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
	parameter RPM_RESOLUTION   = 10                         ;
	parameter PWM_RESOLUTION   = 16                         ;
	parameter DUTY_CYCLE_LIMIT = ((2**PWM_RESOLUTION-1)*3)/4; // limit Duty cycle to 75% of the maximum
	parameter FIFO_RD_DATA_WIDTH = 32*4;
// dc motor has time constant = 100ms
// pwm should be 100 Hz frequency
//*********************************************************************************//
//	SIGNAL DECLARATIONS
//*********************************************************************************//
	// clock enable signals
	logic clk_en_100hz    ;
	logic clk_en_20hz     ;
	logic clk_en_10khz    ;
	logic prev_clk_en_20hz;
	// pwm signals
	logic        [PWM_RESOLUTION-1:0] duty_cycle_l              ;
	logic        [PWM_RESOLUTION-1:0] duty_cycle_r              ;
	logic signed [  PWM_RESOLUTION:0] curr_duty_cycle_l_sig     ;
	logic signed [  PWM_RESOLUTION:0] curr_duty_cycle_r_sig     ;
	logic signed [  PWM_RESOLUTION:0] next_curr_duty_cycle_l_sig;
	logic signed [  PWM_RESOLUTION:0] next_curr_duty_cycle_r_sig;
	logic        [PWM_RESOLUTION-1:0] next_duty_cycle_l_uns     ;
	logic        [PWM_RESOLUTION-1:0] next_duty_cycle_r_uns     ;
	// tachometer signals
	logic [RPM_RESOLUTION-1:0] rpm_l_measured;
	logic [RPM_RESOLUTION-1:0] rpm_r_measured;
	// pid controller signals
	logic        [                      RPM_RESOLUTION-1:0] rpm_l_setpoint         ;
	logic signed [                        PWM_RESOLUTION:0] duty_cycle_l_correction;
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_p_l                  ; // 3:-8
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_i_l                  ;
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_d_l                  ;
	logic        [                      RPM_RESOLUTION-1:0] error_tach_l           ;
	logic        [                      RPM_RESOLUTION-1:0] rpm_r_setpoint         ;
	logic signed [                        PWM_RESOLUTION:0] duty_cycle_r_correction;
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_p_r                  ;
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_i_r                  ;
	logic        [(PWM_RESOLUTION+1-RPM_RESOLUTION-3)-1:-8] k_d_r                  ;
	// FIFO signals
	logic        fifo_ltach_wr_en;
	logic        fifo_ltach_rd_en;
	logic [FIFO_RD_DATA_WIDTH-1:0] fifo_ltach_din  ;
	logic [FIFO_RD_DATA_WIDTH-1:0] fifo_ltach_dout ;
	logic        fifo_ltach_empty;
	logic        fifo_ltach_full ;
	// uart signals
	logic       uart_tx_done ;
	logic       uart_start_tx;
	logic [7:0] uart_tx_din  ;


//*********************************************************************************//
//	MODULE INSTANTIATIONS
//*********************************************************************************//
	clk_enable #(.DIVISOR(1249999)) i_clk_enable_100hz (
		.clk_in  (clk         ),
		.reset_in(reset       ),
		.clk_en  (clk_en_100hz)
	);

	clk_enable #(.DIVISOR(6249999)) i_clk_enable_20hz (
		.clk_in  (clk        ),
		.reset_in(reset      ),
		.clk_en  (clk_en_20hz)
	);

	clk_enable #(.DIVISOR(12499)) i_clk_enable_10khz (
		.clk_in  (clk         ),
		.reset_in(reset       ),
		.clk_en  (clk_en_10khz)
	);

	pwm #(.R(PWM_RESOLUTION)) i_pwm_l (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_l),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_l )
	);

	pwm #(.R(PWM_RESOLUTION)) i_pwm_r (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_r),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_r )
	);

	tachometer_interface i_tachometer_interface_l (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.clk_en             (clk_en_10khz      ),
		.tachometer_pulse_in(tachometer_out_b_l),
		.actual_rpm_out     (rpm_l_measured    )
	);

	tachometer_interface i_tachometer_interface_r (
		.clk_in             (clk               ),
		.reset_in           (reset             ),
		.clk_en             (clk_en_10khz      ),
		.tachometer_pulse_in(tachometer_out_b_r),
		.actual_rpm_out     (rpm_r_measured    )
	);

	pid_controller #(.PID_FRAC_WIDTH(8), .PV_WIDTH(RPM_RESOLUTION), .CONTROL_WIDTH(PWM_RESOLUTION+1)) i_pid_controller_tach_l (
		.clk               (clk                    ),
		.reset             (reset                  ),
		.clk_en            (clk_en_20hz            ),
		.en                (motor_en_sw            ),
		.k_p               (k_p_l                  ),
		.k_i               (k_i_l                  ),
		.k_d               (k_d_l                  ),
		.setpoint          (rpm_l_setpoint         ),
		.feedback          (rpm_l_measured         ),
		.error             (error_tach_l           ),
		.control_signal_out(duty_cycle_l_correction)
	);

	fifo #(.DEPTH_POW_2(10), .DWIDTH(FIFO_RD_DATA_WIDTH)) i_ltach_fifo (
		// left tachometer pid feedback
		.clk  (clk                                                                                                                                           ),
		.rst  (reset                                                                                                                                         ),
		.wr_en(fifo_ltach_wr_en                                                                                                                              ),
		.rd_en(fifo_ltach_rd_en                                                                                                                              ),
		.din  (fifo_ltach_din),
		.dout (fifo_ltach_dout                                                                                                                               ),
		.empty(fifo_ltach_empty                                                                                                                              ),
		.full (fifo_ltach_full                                                                                                                               )
	);

	uart_data_fsm #(.FIFO_RD_DATA_WIDTH(FIFO_RD_DATA_WIDTH)) i_uart_data_fsm (
		.clk          (clk             ),
		.reset        (reset           ),
		.fsm_en       (uart_en_sw      ),
		.uart_tx_done (uart_tx_done    ),
		.uart_start_tx(uart_start_tx   ),
		.uart_tx_din  (uart_tx_din     ),
		.fifo_rd_data (fifo_ltach_dout ),
		.fifo_empty   (fifo_ltach_empty),
		.fifo_rd_en   (fifo_ltach_rd_en)
	);

	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk           ),
		.reset    (reset         ),
		.start    (uart_start_tx ),
		.din      (uart_tx_din   ),
		.serial_tx(uart_serial_tx),
		.done     (uart_tx_done  )
	);

//*********************************************************************************//
// SIGNAL ASSIGNMENTS
//*********************************************************************************//
	assign motor_en_l     = motor_en_sw;
	assign motor_en_r     = motor_en_sw;
	assign k_p_l          = 12'h2FF;
	assign k_i_l          = 0;
	assign k_d_l          = 0;
	assign k_p_r          = 12'h2FF;
	assign k_i_r          = 0;
	assign k_d_r          = 0;
	assign rpm_r_setpoint = 'd100;
	assign rpm_l_setpoint = 'd100;
	assign fifo_ltach_din = {22'd0,rpm_l_measured,{15{duty_cycle_l_correction[PWM_RESOLUTION]}},duty_cycle_l_correction,{22{error_tach_l[RPM_RESOLUTION-1]}},error_tach_l,16'd0,duty_cycle_l};
	// convert duty cycle to signed for addition calculation
	assign curr_duty_cycle_l_sig = {1'd0,duty_cycle_l};
	assign curr_duty_cycle_r_sig = {1'd0,duty_cycle_r};
	// calculate new signed duty cycle
	assign next_curr_duty_cycle_l_sig = curr_duty_cycle_l_sig + duty_cycle_l_correction;
	assign next_curr_duty_cycle_r_sig = curr_duty_cycle_r_sig + duty_cycle_r_correction;
	// if signed duty cycle is negative set to zero
	// if signed duty cycle is over 75% of the maximum set to 75 %
	// PWM_RESOLUTION is 16

	assign next_duty_cycle_l_uns = /*(next_curr_duty_cycle_l_sig >= DUTY_CYCLE_LIMIT) ?  DUTY_CYCLE_LIMIT : (next_curr_duty_cycle_l_sig[PWM_RESOLUTION] ? 0 : */next_curr_duty_cycle_l_sig[PWM_RESOLUTION-1:0];
	assign next_duty_cycle_r_uns = /*((next_curr_duty_cycle_r_sig >= DUTY_CYCLE_LIMIT) ?  DUTY_CYCLE_LIMIT : (next_curr_duty_cycle_r_sig[PWM_RESOLUTION] ? 0 : */next_curr_duty_cycle_r_sig[PWM_RESOLUTION-1:0];

	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			duty_cycle_l <= 0;
			duty_cycle_r <= 0;
		end else begin
			if(clk_en_20hz) begin
				duty_cycle_l <= next_duty_cycle_l_uns ;
				duty_cycle_r <= next_duty_cycle_r_uns ;
			end
		end
	end
	// trigger wr_en if fifo is not full and on negative edge of clk_en and motor is running
	always_ff @(posedge clk or posedge reset) begin 	// wr enable control for fifos
		if(reset) begin
			fifo_ltach_wr_en <= 0;
			//fifo_rtach_wr_en  <= 0;
			prev_clk_en_20hz <= 0;
		end else begin
			prev_clk_en_20hz <= clk_en_20hz;
			if (prev_clk_en_20hz && !clk_en_20hz && !fifo_ltach_full && motor_en_sw) begin
				fifo_ltach_wr_en <= 1;
				//fifo_rtach_wr_en <= 1;
			end else begin
				fifo_ltach_wr_en <= 0;
				//fifo_rtach_wr_en <= 0;
			end
		end
	end






/*
	logic        fifo_ir_wr_en;
	logic        fifo_ir_rd_en;
	logic [15:0] fifo_ir_din  ;
	logic [15:0] fifo_ir_dout ;
	logic        fifo_ir_empty;
	logic        fifo_ir_full ;
	fifo #(.DEPTH_POW_2(8), .DWIDTH(16)) i_ir_fifo (
	// ir sensor pid feedback
	.clk  (clk          ),
	.rst  (reset        ),
	.wr_en(fifo_ir_wr_en),
	.rd_en(fifo_ir_rd_en),
	.din  (fifo_ir_din  ),
	.dout (fifo_ir_dout ),
	.empty(fifo_ir_empty),
	.full (fifo_ir_full )
	);
*/
	/*
	logic       fifo_rtach_wr_en;
	logic       fifo_rtach_rd_en;
	logic [8:0] fifo_rtach_dout ;
	logic       fifo_rtach_empty;
	logic       fifo_rtach_full ;

	fifo #(.DEPTH_POW_2(10), .DWIDTH(9)) i_rtach_fifo (
	// right tachometer pid feedback
	.clk  (clk             ),
	.rst  (reset           ),
	.wr_en(fifo_rtach_wr_en),
	.rd_en(fifo_rtach_rd_en),
	.din  (rpm_r_measured  ),
	.dout (fifo_rtach_dout ),
	.empty(fifo_rtach_empty),
	.full (fifo_rtach_full )
	);

	*/

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





endmodule