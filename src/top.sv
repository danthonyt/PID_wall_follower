module top (
	input  logic       clk           ,
	input  logic       reset         ,
	// pid tuning buttons
	input  logic       btn[0:3]      ,
	// chassis bumper buttons (negative logic)
	input  logic [5:0] bumper_btn    ,
	// i2c interface
	inout  logic       scl_pin       ,
	inout  logic       sda_pin       ,
	// uart interface
	output logic       uart_serial_tx, // sends PID error data
	input  logic       uart_en_sw    , // enables uart communication
	// motor inputs/outputs
	output logic       motor_en      , // enables both motors when high
	output logic       motor_pwm_l   , // pwm drives left/right motor
	output logic       motor_pwm_r
);

// signal
	parameter PWM_RESOLUTION  = 17;
	parameter ADC_RESOLUTION  = 16;
	parameter DIST_RESOLUTION = 7 ;
	// wall follower PID parameters
	parameter PID_WALL_INT_WIDTH    = 16   ;
	parameter PID_WALL_FRAC_WIDTH   = 0    ;
	parameter BASE_DUTY             = 16384;
	parameter MAX_DUTY_CYCLE_OFFSET = 4915 ;
	// tachometer PID parameters
	parameter FIFO_RD_DATA_WIDTH_IR = 32*2;
	// I2C
	parameter MAX_BYTES_PER_TRANSACTION = 3;


//*********************************************************************************//
//	SIGNAL DECLARATIONS
//*********************************************************************************//
	// clock enable
	logic clk_en_32hz     ;
	logic prev_clk_en_32hz;
	// pwm
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_l,next_duty_cycle_l;
	logic unsigned [PWM_RESOLUTION-1:0] duty_cycle_r,next_duty_cycle_r;
	// tachometer
// PID controller
	logic signed [PWM_RESOLUTION:0] duty_cycle_offset;
	// Wall follower PID
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_p                 ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_i                 ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_d                 ;
	logic unsigned [                      DIST_RESOLUTION-1:0] distance_cm_setpoint;
	logic unsigned [                      DIST_RESOLUTION-1:0] distance_cm_measured;
	logic signed   [                        DIST_RESOLUTION:0] distance_cm_error   ;
// FIFO signals

	// ir distance sensor data
	logic                             fifo_ir_wr_en;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_din  ;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_ir_dout ;
	logic                             fifo_ir_empty;
	logic                             fifo_ir_full ;
// uart
	logic                             uart_tx_done   ;
	logic                             uart_start_tx  ;
	logic [                      7:0] uart_tx_din    ;
	logic [FIFO_RD_DATA_WIDTH_IR-1:0] fifo_uart_dout ;
	logic                             fifo_uart_rd_en;
	logic                             fifo_uart_empty;
// i2c
	logic [15:0] adc_data         ;
	logic        btn_debounce[0:3];


	logic [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] sig_0,next_sig_0;
	logic [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] res_0,res_1,res_2,res_3;

	logic nand_bumper_btns          ;
	logic nand_bumper_btns_debounced;


//*********************************************************************************//
//	MODULE INSTANTIATIONS
//*********************************************************************************//
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


	pid_controller #(
		.PID_INT_WIDTH (PID_WALL_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_WALL_FRAC_WIDTH),
		.PV_WIDTH      (DIST_RESOLUTION    ),
		.CONTROL_WIDTH (PWM_RESOLUTION+1   )
	) i_pid_controller (
		.clk        (clk                 ),
		.reset      (reset               ),
		.clk_en     (clk_en_32hz         ),
		.en         (motor_en            ),
		.k_p        (k_p                 ),
		.k_i        (k_i                 ),
		.k_d        (k_d                 ),
		.setpoint   (distance_cm_setpoint),
		.feedback   (distance_cm_measured),
		.error      (distance_cm_error   ),
		.control_out(duty_cycle_offset   )
	);

	i2c_adc_fsm i_i2c_adc_fsm (.clk(clk), .reset(reset), .scl_pin(scl_pin), .sda_pin(sda_pin), .adc_data(adc_data));

	adc_lut i_adc_lut (.clk(clk), .reset(reset), .raw_adc_data(adc_data), .distance_cm_out(distance_cm_measured));
	fifo #(.DEPTH_POW_2(10), .DWIDTH(FIFO_RD_DATA_WIDTH_IR)) i_fifo (
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


	uart_data_fsm #(.FIFO_RD_DATA_WIDTH(FIFO_RD_DATA_WIDTH_IR)) i_uart_data_fsm (
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
	genvar i;
	generate
		for (i = 0; i < 4; i++) begin
			debounce i_debounce (
				.clk   (clk                 ),
				.reset (reset               ),
				.pb_in (btn[i]         ),
				.pb_out(btn_debounce[i])
			);
		end
	endgenerate
	ff_with_clken_clrn #(.D_WIDTH(PWM_RESOLUTION), .RESET_VALUE(0)) i_ff_duty_l (
		.clk   (clk              ),
		.clk_en(clk_en_32hz     ),
		.clr_n (motor_en     ),
		.reset (reset            ),
		.d     (next_duty_cycle_l),
		.q     (duty_cycle_l     )
	);

	ff_with_clken_clrn #(.D_WIDTH(PWM_RESOLUTION), .RESET_VALUE(0)) i_ff_duty_r (
		.clk   (clk              ),
		.clk_en(clk_en_32hz      ),
		.clr_n (motor_en         ),
		.reset (reset            ),
		.d     (next_duty_cycle_r),
		.q     (duty_cycle_r     )
	);
	ff #(.D_WIDTH($size(k_p))) i_ff_k (
		.clk(clk       ),
		.rst(reset     ),
		.d  (next_sig_0),
		.q  (k_p       )
	);
	ff #(.D_WIDTH(1)) i_ff_clken_32hz (
		.clk(clk             ),
		.rst(reset           ),
		.d  (clk_en_32hz     ),
		.q  (prev_clk_en_32hz)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_adder_signed_unsigned_dl (
		.a_unsigned_in(base_duty_cycle  ),
		.b_signed_in  (duty_cycle_offset),
		.sum_out      (next_duty_cycle_r)
	);

	saturating_subtractor_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_sub_signed_unsigned_dr (
		.a_unsigned_in(base_duty_cycle  ),
		.b_signed_in  (duty_cycle_offset),
		.sum_out      (next_duty_cycle_l)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn0 (
		.a_unsigned_in(sig_0),
		.b_signed_in  (10   ),
		.sum_out      (res_0)
	);

	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn1 (
		.a_unsigned_in(sig_0),
		.b_signed_in  (100  ),
		.sum_out      (res_1)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn2 (
		.a_unsigned_in(sig_0),
		.b_signed_in  (-10  ),
		.sum_out      (res_2)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn3 (
		.a_unsigned_in(sig_0),
		.b_signed_in  (-100 ),
		.sum_out      (res_3)
	);

	debounce i_debounce_bumper (
		.clk   (clk                       ),
		.reset (reset                     ),
		.pb_in (nand_bumper_btns          ),
		.pb_out(nand_bumper_btns_debounced)
	);

//*********************************************************************************//
// SIGNAL ASSIGNMENTS
//*********************************************************************************//
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			motor_en <= 0;
		end else if(nand_bumper_btns_debounced) begin
			motor_en <= ~motor_en;
		end
	end
	logic [PWM_RESOLUTION-1:0] base_duty_cycle;
	assign base_duty_cycle      = BASE_DUTY;
	assign nand_bumper_btns     = ~(&bumper_btn); // convert to positive logic for connecting to debounce module
	assign distance_cm_setpoint = 30;
	assign sig_0                = k_p;
	assign next_sig_0           = btn_debounce[0] ? res_0  : (btn_debounce[1] ? res_1 : (btn_debounce[2] ? res_2 : (btn_debounce[3] ? res_3 : sig_0)));
	assign fifo_ir_din          = {{26'd0,distance_cm_measured},{26'd0,distance_cm_setpoint}};
	assign fifo_ir_wr_en        = prev_clk_en_32hz & ~clk_en_32hz & ~fifo_ir_full & motor_en;
	assign fifo_uart_empty      = fifo_ir_empty;
	assign fifo_uart_dout       = fifo_ir_dout;
endmodule
