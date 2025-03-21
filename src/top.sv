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
	parameter PWM_RESOLUTION        = 17;
	parameter TACH_COUNT_RESOLUTION = 8 ;
	parameter ADC_RESOLUTION        = 16;
	parameter DIST_RESOLUTION       = 7 ;
	// wall follower PID parameters
	parameter PID_WALL_INT_WIDTH               = 8                      ;
	parameter PID_WALL_FRAC_WIDTH              = 8                      ;
	parameter PV_WALL_WIDTH                    = DIST_RESOLUTION        ;
	parameter CONTROL_WALL_WIDTH               = TACH_COUNT_RESOLUTION+1;
	parameter BASE_TACHOMETER_EDGE_COUNT       = 12                     ; // base RPM = base_pulse * 4.17
	parameter MAX_TACHOMETER_EDGE_COUNT_OFFSET = 5                      ;

	parameter DISTANCE_CM_SETPOINT = 30; // range of 8 to 56 cm
	// tachometer PID parameters
	parameter EDGE_COUNT_MAX          = 500                      ;
	parameter PID_TACH_INT_WIDTH      = 8                        ;
	parameter PID_TACH_FRAC_WIDTH     = 8                        ;
	parameter PV_TACH_WIDTH           = TACH_COUNT_RESOLUTION    ;
	parameter CONTROL_TACH_WIDTH      = PWM_RESOLUTION+1         ;
	parameter FIFO_RD_DATA_WIDTH_TACH = 32*3                     ;
	parameter FIFO_RD_DATA_WIDTH_IR   = 32*2                     ;
	parameter UART_FIFO_WIDTH         = FIFO_RD_DATA_WIDTH_TACH*2;
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
	// push buttons
	logic p_incr_btn_debounced;
	logic i_incr_btn_debounced;
	logic d_incr_btn_debounced;

	logic tach_count_offset_add_subn;
	// pwm
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_l,next_duty_cycle_l;
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_r,next_duty_cycle_r;
	// tachometer
	logic unsigned [TACH_COUNT_RESOLUTION-1:0] tach_count_measured_l,tach_count_setpoint_l,next_tach_count_setpoint_l;
	logic unsigned [TACH_COUNT_RESOLUTION-1:0] tach_count_measured_r,tach_count_setpoint_r,next_tach_count_setpoint_r;
	logic signed   [  TACH_COUNT_RESOLUTION:0] tach_count_error_l,tach_count_error_r;
	logic unsigned [TACH_COUNT_RESOLUTION-1:0] base_tach_count      ;
	logic signed   [  TACH_COUNT_RESOLUTION:0] tach_count_offset    ;
// PID controller
	// tachometer PID
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_p_tach           ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_i_tach           ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_d_tach           ;
	logic signed   [                   CONTROL_TACH_WIDTH-1:0] duty_cycle_offset_l;
	logic signed   [                   CONTROL_TACH_WIDTH-1:0] duty_cycle_offset_r;
	// Wall follower PID
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_p_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_i_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_d_wall            ;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_setpoint;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_measured;
	logic signed   [                          PV_WALL_WIDTH:0] distance_cm_error   ;
// FIFO signals
	// tachometer
	logic                               fifo_ltach_wr_en;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_ltach_din  ;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_ltach_dout ;
	logic                               fifo_ltach_empty;
	logic                               fifo_ltach_full ;

	logic                               fifo_rtach_wr_en;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_rtach_din  ;
	logic [FIFO_RD_DATA_WIDTH_TACH-1:0] fifo_rtach_dout ;
	logic                               fifo_rtach_empty;
	logic                               fifo_rtach_full ;
	// ir distance sensor data
	logic                             fifo_ir_wr_en;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_din  ;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_dout ;
	logic                             fifo_ir_empty;
	logic                             fifo_ir_full ;
// uart
	logic                       uart_tx_done   ;
	logic                       uart_start_tx  ;
	logic [                7:0] uart_tx_din    ;
	logic [UART_FIFO_WIDTH-1:0] fifo_uart_dout ;
	logic                       fifo_uart_rd_en;
	logic                       fifo_uart_empty;
// i2c
	logic [15:0] adc_data;

	logic [7:-8] sig_1,sig_2,sig_3;

//*********************************************************************************//
//	MODULE INSTANTIATIONS
//*********************************************************************************//

	ila_0 testing_ila (
		.clk   (clk                  ), // input wire clk
		
		
		.probe0(clk_en_100hz         ), // input wire [0:0]  probe0
		.probe1(tach_count_measured_l), // input wire [7:0]  probe1
		.probe2(tach_count_measured_r), // input wire [7:0]  probe2
		.probe3(tach_count_setpoint_l), // input wire [7:0]  probe3
		.probe4(tach_count_setpoint_r), // input wire [7:0]  probe4
		.probe5(duty_cycle_offset_l  ), // input wire [17:0]  probe5
		.probe6(duty_cycle_offset_r  )  // input wire [17:0]  probe6
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
		// 100 Hz freqency
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



	tachometer_edge_counter #(.EDGE_COUNT_RESOLUTION(TACH_COUNT_RESOLUTION)) i_tachometer_edge_counter_l (
		.clk_in          (clk                  ),
		.reset_in        (reset                ),
		.tachometer_out_a(tachometer_out_a_l   ),
		.tachometer_out_b(tachometer_out_b_l   ),
		.edge_count_o    (tach_count_measured_l)
	);


	tachometer_edge_counter #(.EDGE_COUNT_RESOLUTION(TACH_COUNT_RESOLUTION)) i_tachometer_edge_counter_r (
		.clk_in          (clk                  ),
		.reset_in        (reset                ),
		.tachometer_out_a(tachometer_out_a_r   ),
		.tachometer_out_b(tachometer_out_b_r   ),
		.edge_count_o    (tach_count_measured_r)
	);

	pid_controller #(
		.PID_INT_WIDTH (PID_TACH_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_TACH_FRAC_WIDTH),
		.PV_WIDTH      (PV_TACH_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_TACH_WIDTH )
	) i_pid_controller_tach_l (
		.clk        (clk                  ),
		.reset      (reset                ),
		.clk_en     (clk_en_100hz         ),
		.en         (motor_en_sw          ),
		.k_p        (k_p_tach             ),
		.k_i        (k_i_tach             ),
		.k_d        (k_d_tach             ),
		.setpoint   (tach_count_setpoint_l),
		.feedback   (tach_count_measured_l),
		.error      (tach_count_error_l   ),
		.control_out(duty_cycle_offset_l  )
	);

	pid_controller #(
		.PID_INT_WIDTH (PID_TACH_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_TACH_FRAC_WIDTH),
		.PV_WIDTH      (PV_TACH_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_TACH_WIDTH )
	) i_pid_controller_tach_r (
		.clk        (clk                  ),
		.reset      (reset                ),
		.clk_en     (clk_en_100hz         ),
		.en         (motor_en_sw          ),
		.k_p        (k_p_tach             ),
		.k_i        (k_i_tach             ),
		.k_d        (k_d_tach             ),
		.setpoint   (tach_count_setpoint_r),
		.feedback   (tach_count_measured_r),
		.error      (tach_count_error_r   ),
		.control_out(duty_cycle_offset_r  )
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
		.control_out(tach_count_offset   )
	);

	i2c_adc_fsm i_i2c_adc_fsm (.clk(clk), .reset(reset), .scl_pin(scl_pin), .sda_pin(sda_pin), .adc_data(adc_data));

	adc_lut i_adc_lut (.clk(clk), .reset(reset), .raw_adc_data(adc_data), .distance_cm_out(distance_cm_measured));

	fifo #(.DEPTH_POW_2(10), .DWIDTH(FIFO_RD_DATA_WIDTH_TACH)) i_ltach_fifo (
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
	fifo #(.DEPTH_POW_2(10), .DWIDTH(FIFO_RD_DATA_WIDTH_TACH)) i_rtach_fifo (
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
	fifo #(.DEPTH_POW_2(10), .DWIDTH(FIFO_RD_DATA_WIDTH_IR)) i_ir_fifo (
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


	uart_data_fsm #(.FIFO_RD_DATA_WIDTH(UART_FIFO_WIDTH)) i_uart_data_fsm (
		.clk          (clk            ),
		.reset        (reset          ),
		.fsm_en       (uart_en_sw     ),
		.uart_tx_done (uart_tx_done   ),
		.uart_start_tx(uart_start_tx  ),
		.uart_tx_din  (uart_tx_din    ),
		.fifo_rd_data (fifo_uart_dout ),
		.fifo_empty   (fifo_uart_empty),
		.fifo_rd_en   (fifo_uart_rd_en)
	);

	uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(1085)) i_uart_tx (
		.clk      (clk           ),
		.reset    (reset         ),
		.start    (uart_start_tx ),
		.din      (uart_tx_din   ),
		.serial_tx(uart_serial_tx),
		.done     (uart_tx_done  )
	);

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


	ff #(.D_WIDTH(PWM_RESOLUTION), .RESET_VALUE((2**PWM_RESOLUTION-1)/4)) i_ff_tachl (
		.clk   (clk              ),
		.clk_en(clk_en_100hz     ),
		.clr_n (motor_en_sw      ),
		.reset (reset            ),
		.d     (next_duty_cycle_l),
		.q     (duty_cycle_l     )
	);

	ff #(.D_WIDTH(PWM_RESOLUTION), .RESET_VALUE((2**PWM_RESOLUTION-1)/4)) i_ff_tachr (
		.clk   (clk              ),
		.clk_en(clk_en_100hz     ),
		.clr_n (motor_en_sw      ),
		.reset (reset            ),
		.d     (next_duty_cycle_r),
		.q     (duty_cycle_r     )
	);

	ff #(.D_WIDTH(TACH_COUNT_RESOLUTION), .RESET_VALUE(0)) i_ff_irl (
		.clk   (clk                       ),
		.clk_en(clk_en_32hz               ),
		.clr_n (motor_en_sw               ),
		.reset (reset                     ),
		.d     (next_tach_count_setpoint_l),
		.q     (tach_count_setpoint_l     )
	);

	ff #(.D_WIDTH(TACH_COUNT_RESOLUTION), .RESET_VALUE(0)) i_ff_irr (
		.clk   (clk                       ),
		.clk_en(clk_en_32hz               ),
		.clr_n (motor_en_sw               ),
		.reset (reset                     ),
		.d     (next_tach_count_setpoint_r),
		.q     (tach_count_setpoint_r     )
	);

	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_adder_signed_unsigned_dl (
		.a_unsigned_in(duty_cycle_l       ),
		.b_signed_in  (duty_cycle_offset_l),
		.sum_out      (next_duty_cycle_l  )
	);

	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_adder_signed_unsigned_dr (
		.a_unsigned_in(duty_cycle_r       ),
		.b_signed_in  (duty_cycle_offset_r),
		.sum_out      (next_duty_cycle_r  )
	);
	/*
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(TACH_COUNT_RESOLUTION)) i_saturating_adder_signed_unsigned_tr (
		.a_unsigned_in(base_tach_count     ),
		.b_signed_in  (tach_count_offset         ),
		.sum_out      (next_tach_count_setpoint_r)
	);
	saturating_subtractor_signed_unsigned #(.UNSIGNED_WIDTH(TACH_COUNT_RESOLUTION)) i_saturating_subtractor_signed_unsigned_tl (
		.a_unsigned_in(base_tach_count     ),
		.b_signed_in  (tach_count_offset         ),
		.sum_out      (next_tach_count_setpoint_l)
	);
	*/
	assign next_tach_count_setpoint_l = 7;
	assign next_tach_count_setpoint_r = 7;


//*********************************************************************************//
// SIGNAL ASSIGNMENTS
//*********************************************************************************//
	assign motor_en = motor_en_sw;
	assign k_p_tach = sig_1;
	assign k_i_tach = sig_2;
	assign k_d_tach = sig_3;

	assign k_p_wall = 16'h0040;
	assign k_i_wall = 0;
	assign k_d_wall = 0;

	assign distance_cm_setpoint = DISTANCE_CM_SETPOINT;
	assign base_tach_count      = BASE_TACHOMETER_EDGE_COUNT;
	// estimated K_p for stable oscillation is 0x0100

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			sig_1 <= 16'h0F00;
			sig_2 <= 16'h0000;
			sig_3 <= 16'h0000;
		end else begin
			if(p_incr_btn_debounced) 
				sig_1 <= sig_1 + 16'h0100;
			else if (i_incr_btn_debounced)
				sig_2 <= sig_2 + 16'h0100;
			else if (d_incr_btn_debounced)
				sig_3 <= sig_3 + 16'h0100;
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
	assign fifo_ltach_din = {{24'd0,tach_count_measured_l},{24'd0,tach_count_setpoint_l},{{23{tach_count_error_l[TACH_COUNT_RESOLUTION]}},tach_count_error_l}};
	assign fifo_rtach_din = {{24'd0,tach_count_measured_r},{24'd0,tach_count_setpoint_r},{{23{tach_count_error_r[TACH_COUNT_RESOLUTION]}},tach_count_error_r}};
	assign fifo_ir_din    = {{26'd0,distance_cm_measured},{26'd0,distance_cm_setpoint}};

	assign fifo_ir_wr_en    = prev_clk_en_32hz & ~clk_en_32hz & ~fifo_ir_full & motor_en_sw;
	assign fifo_ltach_wr_en = prev_clk_en_100hz & ~clk_en_100hz & ~fifo_ltach_full & motor_en_sw;
	assign fifo_rtach_wr_en = prev_clk_en_100hz & ~clk_en_100hz & ~fifo_rtach_full & motor_en_sw;

	assign fifo_uart_dout = {fifo_ltach_dout,fifo_rtach_dout};
	//assign fifo_uart_dout = fifo_ir_dout;
endmodule
