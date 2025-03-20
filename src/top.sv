module top (
	input  logic clk               ,
	input  logic reset             ,
	// pid tuning buttons
	input  logic p_incr_btn        ,
	input  logic i_incr_btn        ,
	input  logic d_incr_btn        ,
	// i2c interface
	inout  logic scl_pin           ,
	inout  logic sda_pin           ,
	// uart interface
	output logic uart_serial_tx    , // sends PID error data
	input  logic uart_en_sw        , // enables uart communication
	// tachometer inputs
	input  logic tachometer_out_a_l,
	input  logic tachometer_out_a_r,
	input  logic tachometer_out_b_l, // use to measure pwm of left/right motor
	input  logic tachometer_out_b_r,
	// motor inputs/outputs
	input  logic motor_en_sw       , // switch input for motor enable
	output logic motor_en          , // enables both motors when high
	output logic motor_pwm_l       , // pwm drives left/right motor
	output logic motor_pwm_r
);

// signal
	parameter PWM_RESOLUTION  = 17;
	parameter RPM_RESOLUTION  = 10;
	parameter ADC_RESOLUTION  = 16;
	parameter DIST_RESOLUTION = 7 ;
	// wall follower PID parameters
	parameter PID_WALL_INT_WIDTH  = 8               ;
	parameter PID_WALL_FRAC_WIDTH = 8               ;
	parameter PV_WALL_WIDTH       = DIST_RESOLUTION ;
	parameter CONTROL_WALL_WIDTH  = RPM_RESOLUTION+1;
	parameter MAX_RPM_OFFSET      = 15              ;
	// tachometer PID parameters
	parameter EDGE_COUNT_MAX          = 500             ;
	parameter PID_TACH_INT_WIDTH      = 8               ;
	parameter PID_TACH_FRAC_WIDTH     = 8               ;
	parameter PV_TACH_WIDTH           = RPM_RESOLUTION  ;
	parameter CONTROL_TACH_WIDTH      = PWM_RESOLUTION+1;
	parameter FIFO_RD_DATA_WIDTH_TACH = 32              ;
	parameter FIFO_RD_DATA_WIDTH_IR   = 32              ;
	parameter FIFO_RD_DATA_WIDTH      = 32*3            ;
	// I2C
	parameter MAX_BYTES_PER_TRANSACTION = 3;
// dc motor has time constant = 100ms
// pwm should be 100 Hz frequency


//*********************************************************************************//
//	SIGNAL DECLARATIONS
//*********************************************************************************//
	// clock enable
	logic clk_en_100hz     ;
	logic clk_en_32hz      ;
	logic prev_clk_en_32hz ;
	logic prev_clk_en_100hz;
	// pwm
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_l                 ;
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_r                 ;
	logic signed   [  PWM_RESOLUTION:0] curr_duty_cycle_l_sig        ;
	logic signed   [  PWM_RESOLUTION:0] curr_duty_cycle_r_sig        ;
	logic signed   [  PWM_RESOLUTION:0] next_curr_duty_cycle_l_signed;
	logic signed   [  PWM_RESOLUTION:0] next_curr_duty_cycle_r_signed;
	logic unsigned [PWM_RESOLUTION-1:0] next_duty_cycle_l            ;
	logic unsigned [PWM_RESOLUTION-1:0] next_duty_cycle_r            ;
	// tachometer
	//logic unsigned [RPM_RESOLUTION-1:0] rpm_measured_l;
	//logic unsigned [RPM_RESOLUTION-1:0] rpm_measured_r;
// PID controller
	// tachometer
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_p_tach           ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_i_tach           ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_d_tach           ;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_setpoint_l     ;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_measured_l     ;
	logic signed   [                          PV_TACH_WIDTH:0] rpm_error_l        ;
	logic signed   [                   CONTROL_TACH_WIDTH-1:0] duty_cycle_offset_l;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_setpoint_r     ;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_measured_r     ;
	logic signed   [                          PV_TACH_WIDTH:0] rpm_error_r        ;
	logic signed   [                   CONTROL_TACH_WIDTH-1:0] duty_cycle_offset_r;



	// ir distance sensor
	logic          [                       RPM_RESOLUTION-1:0] base_rpm            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_p_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_i_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_d_wall            ;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_setpoint;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_measured;
	logic signed   [                          PV_WALL_WIDTH:0] distance_cm_error   ;
	logic signed   [                   CONTROL_WALL_WIDTH-1:0] rpm_offset          ;
// FIFO signals
	// tachometer
	logic                               fifo_ltach_wr_en;
	logic                               fifo_ltach_rd_en;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_ltach_din  ;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_ltach_dout ;
	logic                               fifo_ltach_empty;
	logic                               fifo_ltach_full ;

	logic                               fifo_rtach_wr_en;
	logic                               fifo_rtach_rd_en;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_rtach_din  ;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_rtach_dout ;
	logic                               fifo_rtach_empty;
	logic                               fifo_rtach_full ;
	// ir distance sensor data
	logic                             fifo_ir_wr_en;
	logic                             fifo_ir_rd_en;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_din  ;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_dout ;
	logic                             fifo_ir_empty;
	logic                             fifo_ir_full ;
// uart
	logic                          uart_tx_done   ;
	logic                          uart_start_tx  ;
	logic [                   7:0] uart_tx_din    ;
	logic [FIFO_RD_DATA_WIDTH-1:0] fifo_uart_dout ;
	logic                          fifo_uart_rd_en;
	logic                          fifo_uart_empty;
// i2c
	logic [15:0] adc_data;


//*********************************************************************************//
//	MODULE INSTANTIATIONS
//*********************************************************************************//

	ila_0 your_instance_name (
		.clk   (clk                 ), // input wire clk
		
		
		.probe0(distance_cm_measured), // input wire [6:0]  probe0
		.probe1(rpm_measured_l      ), // input wire [9:0]  probe1
		.probe2(rpm_measured_r      ), // input wire [9:0]  probe2
		.probe3(clk_en_32hz         ), // input wire [0:0]  probe3
		.probe4(duty_cycle_l        ), // input wire [16:0]  probe4
		.probe5(k_p_wall        )  // input wire [16:0]  probe5
	);

	clk_enable #(.DIVISOR(1249999)) i_clk_enable_100hz (
		.clk_in  (clk         ),
		.reset_in(reset       ),
		.clk_en  (clk_en_100hz)
	);

	clk_enable #(.DIVISOR(3910000-1)) i_clk_enable_32hz (
		.clk_in  (clk        ),
		.reset_in(reset      ),
		.clk_en  (clk_en_32hz)
	);

	pwm #(.R(PWM_RESOLUTION-1)) i_pwm_l (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_l),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_l )
	);

	pwm #(.R(PWM_RESOLUTION-1)) i_pwm_r (
		.clk    (clk         ),
		.reset  (reset       ),
		.duty   (duty_cycle_r),
		.dvsr   ('d18        ),
		.pwm_out(motor_pwm_r )
	);

	tachometer_interface #(.EDGE_COUNT_MAX(EDGE_COUNT_MAX)) i_tachometer_interface_l (
		.clk_in          (clk               ),
		.reset_in        (reset             ),
		.tachometer_out_a(tachometer_out_a_l),
		.tachometer_out_b(tachometer_out_b_l),
		.actual_rpm_out  (rpm_measured_l    )
	);

	tachometer_interface #(.EDGE_COUNT_MAX(EDGE_COUNT_MAX)) i_tachometer_interface_r (
		.clk_in          (clk               ),
		.reset_in        (reset             ),
		.tachometer_out_a(tachometer_out_a_r),
		.tachometer_out_b(tachometer_out_b_r),
		.actual_rpm_out  (rpm_measured_r    )
	);

	pid_controller #(
		.PID_INT_WIDTH (PID_TACH_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_TACH_FRAC_WIDTH),
		.PV_WIDTH      (PV_TACH_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_TACH_WIDTH )
	) i_pid_controller_tach_l (
		.clk        (clk                ),
		.reset      (reset              ),
		.clk_en     (clk_en_100hz       ),
		.en         (motor_en_sw        ),
		.k_p        (k_p_tach           ),
		.k_i        (k_i_tach           ),
		.k_d        (k_d_tach           ),
		.setpoint   (rpm_setpoint_l     ),
		.feedback   (rpm_measured_l     ),
		.error      (rpm_error_l        ),
		.control_out(duty_cycle_offset_l)
	);

	pid_controller #(
		.PID_INT_WIDTH (PID_TACH_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_TACH_FRAC_WIDTH),
		.PV_WIDTH      (PV_TACH_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_TACH_WIDTH )
	) i_pid_controller_tach_r (
		.clk        (clk                ),
		.reset      (reset              ),
		.clk_en     (clk_en_100hz       ),
		.en         (motor_en_sw        ),
		.k_p        (k_p_tach           ),
		.k_i        (k_i_tach           ),
		.k_d        (k_d_tach           ),
		.setpoint   (rpm_setpoint_r     ),
		.feedback   (rpm_measured_r     ),
		.error      (rpm_error_r        ),
		.control_out(duty_cycle_offset_r)
	);

	pid_controller #(
		.PID_INT_WIDTH (PID_WALL_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_WALL_FRAC_WIDTH),
		.PV_WIDTH      (PV_WALL_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_WALL_WIDTH )
	) i_pid_controller_ir (
		.clk        (clk                 ),
		.reset      (reset               ),
		.clk_en     (clk_en_32hz         ),
		.en         (motor_en_sw         ),
		.k_p        (k_p_wall            ),
		.k_i        (k_i_wall            ),
		.k_d        (k_d_wall            ),
		.setpoint   (distance_cm_setpoint),
		.feedback   (distance_cm_measured),
		.error      (distance_cm_error   ),
		.control_out(rpm_offset          )
	);

	motor_control #(
		.RPM_RESOLUTION(RPM_RESOLUTION),
		.PWM_RESOLUTION(PWM_RESOLUTION),
		.MAX_RPM_OFFSET(MAX_RPM_OFFSET)
	) i_motor_control (
		.clk                (clk                ),
		.clk_en_adc         (clk_en_32hz        ),
		.clk_en_tach        (clk_en_100hz       ),
		.reset              (reset              ),
		.duty_cycle_offset_l(duty_cycle_offset_l), // TODO: Check connection ! Signal/port not matching : Expecting logic [PWM_RESOLUTION:0]  -- Found logic [CONTROL_TACH_WIDTH-1:0]
		.duty_cycle_offset_r(duty_cycle_offset_r), // TODO: Check connection ! Signal/port not matching : Expecting logic [PWM_RESOLUTION:0]  -- Found logic [CONTROL_TACH_WIDTH-1:0]
		.base_rpm           (base_rpm           ),
		.rpm_offset         (rpm_offset         ), // TODO: Check connection ! Signal/port not matching : Expecting logic [RPM_RESOLUTION:0]  -- Found logic [CONTROL_WALL_WIDTH-1:0]
		.duty_cycle_l       (duty_cycle_l       ),
		.duty_cycle_r       (duty_cycle_r       ),
		.rpm_setpoint_l     (rpm_setpoint_l     ), // TODO: Check connection ! Signal/port not matching : Expecting logic [RPM_RESOLUTION-1:0]  -- Found logic [PV_TACH_WIDTH-1:0]
		.rpm_setpoint_r     (rpm_setpoint_r     )  // TODO: Check connection ! Signal/port not matching : Expecting logic [RPM_RESOLUTION-1:0]  -- Found logic [PV_TACH_WIDTH-1:0]
	);

	i2c_adc_fsm i_i2c_adc_fsm (.clk(clk), .reset(reset), .scl_pin(scl_pin), .sda_pin(sda_pin), .adc_data(adc_data));

	adc_lut i_adc_lut (.clk(clk), .reset(reset), .raw_adc_data(adc_data), .distance_cm_out(distance_cm_measured));



/*
	genvar i;
	generate
	for (i = 0; i < 4; i++) begin
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_ltach_fifo (
	// left tachometer pid feedback
	.clk  (clk             ),
	.rst  (reset           ),
	.wr_en(fifo_ltach_wr_en),
	.rd_en(fifo_ltach_rd_en),
	.din  (fifo_ltach_din[i]),
	.dout (fifo_ltach_dout[i] ),
	.empty(fifo_ltach_empty),
	.full (fifo_ltach_full )
	);
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_rtach_fifo (
	// left tachometer pid feedback
	.clk  (clk               ),
	.rst  (reset             ),
	.wr_en(fifo_rtach_wr_en  ),
	.rd_en(fifo_rtach_rd_en  ),
	.din  (fifo_rtach_din[i] ),
	.dout (fifo_rtach_dout[i]),
	.empty(fifo_rtach_empty  ),
	.full (fifo_rtach_full   )
	);
	if(i < 3) begin
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_ir_fifo (
	// ir sensor pid feedback
	.clk  (clk          ),
	.rst  (reset        ),
	.wr_en(fifo_ir_wr_en),
	.rd_en(fifo_ir_rd_en),
	.din  (fifo_ir_din[i]  ),
	.dout (fifo_ir_dout[i] ),
	.empty(fifo_ir_empty),
	.full (fifo_ir_full )
	);
	end
	end
	endgenerate
	*/
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_ltach_fifo (
		// left tachometer pid feedback
		.clk  (clk             ),
		.rst  (reset           ),
		.wr_en(fifo_ltach_wr_en),
		.rd_en(fifo_uart_rd_en ),
		.din  (fifo_ltach_din  ),
		.dout (fifo_ltach_dout ),
		.empty(fifo_ltach_empty),
		.full (fifo_ltach_full )
	);
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_rtach_fifo (
		// left tachometer pid feedback
		.clk  (clk             ),
		.rst  (reset           ),
		.wr_en(fifo_rtach_wr_en),
		.rd_en(fifo_uart_rd_en ),
		.din  (fifo_rtach_din  ),
		.dout (fifo_rtach_dout ),
		.empty(fifo_rtach_empty),
		.full (fifo_rtach_full )
	);
	fifo #(.DEPTH_POW_2(10), .DWIDTH(32)) i_ir_fifo (
		// ir sensor pid feedback
		.clk  (clk            ),
		.rst  (reset          ),
		.wr_en(fifo_ir_wr_en  ),
		.rd_en(fifo_uart_rd_en),
		.din  (fifo_ir_din    ),
		.dout (fifo_ir_dout   ),
		.empty(fifo_ir_empty  ),
		.full (fifo_ir_full   )
	);


	uart_data_fsm #(.FIFO_RD_DATA_WIDTH(FIFO_RD_DATA_WIDTH)) i_uart_data_fsm (
		.clk          (clk            ),
		.reset        (reset          ),
		.fsm_en       (uart_en_sw     ),
		.uart_tx_done (uart_tx_done   ),
		.uart_start_tx(uart_start_tx  ),
		.uart_tx_din  (uart_tx_din    ),
		///*
		.fifo_rd_data (fifo_uart_dout ),
		.fifo_empty   (fifo_uart_empty),
		.fifo_rd_en   (fifo_uart_rd_en)
		//*/
		/*
		.fifo_rd_data (fifo_ir_dout   ),
		.fifo_empty   (fifo_ir_empty  ),
		.fifo_rd_en   (fifo_ir_rd_en  ),
		*/
	);

	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk           ),
		.reset    (reset         ),
		.start    (uart_start_tx ),
		.din      (uart_tx_din   ),
		.serial_tx(uart_serial_tx),
		.done     (uart_tx_done  )
	);


	logic p_incr_btn_debounced;
	logic i_incr_btn_debounced;
	logic d_incr_btn_debounced;

	debounce i_debounce_p (
		.clk   (clk                 ),
		.reset (reset               ),
		.pb_in (p_incr_btn          ),
		.pb_out(p_incr_btn_debounced)
	);

	debounce i_debounce_i (
		.clk   (clk                 ),
		.reset (reset               ),
		.pb_in (i_incr_btn          ),
		.pb_out(i_incr_btn_debounced)
	);

	debounce i_debounce_d (
		.clk   (clk                 ),
		.reset (reset               ),
		.pb_in (d_incr_btn          ),
		.pb_out(d_incr_btn_debounced)
	);

//*********************************************************************************//
// SIGNAL ASSIGNMENTS
//*********************************************************************************//
	assign motor_en = motor_en_sw;
	assign k_p_tach = 16'h0F00;
	assign k_i_tach = 0;
	assign k_d_tach = 0;
	//assign k_p_wall             = 16'h00F0;
	
	assign distance_cm_setpoint = 'd20;	// distance to wall should be 20 cm
	assign base_rpm             = 50;
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			k_p_wall <= 16'h0080;
			 k_i_wall <= 16'h0000;
			k_d_wall             <= 16'h0100;
		end else begin
			if(p_incr_btn_debounced)
				k_p_wall <= k_p_wall + 16'h0010;
			else if (i_incr_btn_debounced)
				k_i_wall <= k_i_wall + 16'h0010;
			else if (d_incr_btn_debounced)
				k_d_wall <= k_d_wall + 16'h0010;
		end
	end
	// Logic for testing
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			prev_clk_en_32hz  <= 0;
			prev_clk_en_100hz <= 0;
		end else begin
			prev_clk_en_32hz  <= clk_en_32hz;
			prev_clk_en_100hz <= clk_en_100hz;
		end
	end
	assign fifo_ltach_din = {22'd0,rpm_measured_l};
	assign fifo_rtach_din = {22'd0,rpm_measured_r};
	assign fifo_ir_din    = {26'd0,distance_cm_measured};
	/*
	assign fifo_ltach_din[1] = {{15{duty_cycle_offset_l[PWM_RESOLUTION]}},duty_cycle_offset_l};
	assign fifo_ltach_din[2] = {{21{rpm_error_l[RPM_RESOLUTION-1]}},rpm_error_l};
	assign fifo_ltach_din[3] = {16'd0,duty_cycle_l};
	assign fifo_rtach_din[1] = {{15{duty_cycle_offset_r[PWM_RESOLUTION]}},duty_cycle_offset_r};
	assign fifo_rtach_din[2] = {{21{rpm_error_r[RPM_RESOLUTION-1]}},rpm_error_r};
	assign fifo_rtach_din[3] = {16'd0,duty_cycle_r};
	assign fifo_ir_din[1]    = {{21{rpm_offset[RPM_RESOLUTION]}},rpm_offset};
	assign fifo_ir_din[2]    = {{24{distance_cm_error[DIST_RESOLUTION]}},distance_cm_error};
	*/
	assign fifo_ir_wr_en    = prev_clk_en_100hz & ~clk_en_100hz & ~fifo_ir_full & motor_en_sw;
	assign fifo_ltach_wr_en = prev_clk_en_100hz & ~clk_en_100hz & ~fifo_ltach_full & motor_en_sw;
	assign fifo_rtach_wr_en = prev_clk_en_100hz & ~clk_en_100hz & ~fifo_rtach_full & motor_en_sw;

	assign fifo_uart_dout = {fifo_ltach_dout,fifo_rtach_dout,fifo_ir_dout};
endmodule