module top (
	input  logic       clk           ,
	input  logic       reset         ,
	// pid tuning buttons
	input  logic       btn[0:3]      ,
	input  logic       motor_en_sw   ,
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
	localparam PWM_RESOLUTION  = 17;
	localparam ADC_RESOLUTION  = 16;
	localparam DIST_RESOLUTION = 7 ;
	// wall follower PID parameters
	localparam PID_INT_WIDTH           = 16                ;
	localparam PV_WIDTH                = DIST_RESOLUTION   ;
	localparam DUTY_CYCLE_OFFSET_WIDTH = PWM_RESOLUTION + 1;
	localparam BASE_DUTY               = 32768             ;
	localparam MAX_DUTY_CYCLE_OFFSET   = 16384             ;
	// tachometer PID parameters
	localparam FIFO_RD_DATA_WIDTH_IR = 32*7;
	// I2C
	localparam MAX_BYTES_PER_TRANSACTION = 3;
	// PID initial values
	localparam INITIAL_PROPORTIONAL = 0;
	localparam INITIAL_INTEGRAL     = 0  ;
	localparam INITIAL_DERIVATIVE   = 0  ;
	// PID debugging
	localparam ERROR_WIDTH        = DIST_RESOLUTION + 1          ;
	localparam PROPORTIONAL_WIDTH = PID_INT_WIDTH + ERROR_WIDTH  ;
	localparam INTEGRAL_WIDTH     = PID_INT_WIDTH + ERROR_WIDTH  ;
	localparam DERIVATIVE_WIDTH   = PID_INT_WIDTH + ERROR_WIDTH+1;


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
	logic signed [DUTY_CYCLE_OFFSET_WIDTH-1:0] duty_cycle_offset    ;
	logic        [         PWM_RESOLUTION-1:0] base_duty_cycle      ;
	logic signed [DUTY_CYCLE_OFFSET_WIDTH-1:0] duty_cycle_offset_adj;
	// Wall follower PID
	logic unsigned [     PID_INT_WIDTH-1:0] k_p                   ;
	logic unsigned [     PID_INT_WIDTH-1:0] k_i                   ;
	logic unsigned [     PID_INT_WIDTH-1:0] k_d                   ;
	logic unsigned [   DIST_RESOLUTION-1:0] distance_diag_setpoint;
	logic unsigned [   DIST_RESOLUTION-1:0] distance_diag         ;
	logic signed   [       ERROR_WIDTH-1:0] distance_error        ;
	logic signed   [PROPORTIONAL_WIDTH-1:0] p_term                ;
	logic signed   [    INTEGRAL_WIDTH-1:0] i_term                ;
	logic signed   [  DERIVATIVE_WIDTH-1:0] d_term                ;

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
	logic signed [15:0] adc_data_diag,adc_data_diag_avg;
	logic               btn_debounce [0:3];


	logic [PID_INT_WIDTH-1:0] sig_0,sig_1,
		next_k_p,next_k_i,next_k_d,
		modify_sig1,modiy_sig0;
	logic [PID_INT_WIDTH-1:0] incr_sig_0,decr_sig_0,incr_sig_1,decr_sig_1;

	logic nand_bumper_btns          ;
	logic nand_bumper_btns_debounced;


//*********************************************************************************//
//	MODULE INSTANTIATIONS
//*********************************************************************************//
	ila_0 pid_data (
		.clk   (clk              ), // input wire clk
		
		
		.probe0(adc_data_diag    ), // input wire [15:0]  probe0
		.probe1(adc_data_diag_avg), // input wire [15:0]  probe1
		.probe2(k_p              ), // input wire [15:0]  probe2
		.probe3(k_i              ), // input wire [15:0]  probe3
		.probe4(k_d              ), // input wire [15:0]  probe4
		.probe5(distance_diag    )  // input wire [6:0]  probe5
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


	pid_controller #(
		.PID_INT_WIDTH(PID_INT_WIDTH          ),
		.PV_WIDTH     (DIST_RESOLUTION        ),
		.CONTROL_WIDTH(DUTY_CYCLE_OFFSET_WIDTH)
	) i_pid_controller (
		.clk        (clk                   ),
		.reset      (reset                 ),
		.clk_en     (clk_en_32hz           ),
		.en         (motor_en              ),
		.k_p        (k_p                   ),
		.k_i        (k_i                   ),
		.k_d        (k_d                   ),
		.setpoint   (distance_diag_setpoint),
		.feedback   (distance_diag         ),
		.control_out(duty_cycle_offset     ),
		.error      (distance_error        ),
		.u_p        (p_term),
		.u_i        (i_term),
		.u_d        (d_term)
	);

	i2c_adc_fsm i_i2c_adc_fsm (
		.clk         (clk              ),
		.reset       (reset            ),
		.scl_pin     (scl_pin          ),
		.sda_pin     (sda_pin          ),
		.adc_data    (adc_data_diag    ),
		.adc_data_avg(adc_data_diag_avg)
	);

	adc_lut i_adc_lut (
		.clk          (clk          ),
		.reset        (reset        ),
		.adc_data_diag(adc_data_diag),
		.distance_diag(distance_diag)
	);
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
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_adder_signed_unsigned_dr (
		.a_unsigned_in(base_duty_cycle      ),
		.b_signed_in  (duty_cycle_offset_adj),
		.sum_out      (next_duty_cycle_r    )
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH(PWM_RESOLUTION)) i_saturating_adder_signed_unsigned_dl (
		.a_unsigned_in(base_duty_cycle      ),
		.b_signed_in  (-duty_cycle_offset_adj),
		.sum_out      (next_duty_cycle_l    )
	);
	ff #(.D_WIDTH($size(k_p)), .RESET_VALUE(INITIAL_PROPORTIONAL)) i_ff_p (
		.clk(clk     ),
		.rst(reset   ),
		.d  (next_k_p),
		.q  (k_p     )
	);
	ff #(.D_WIDTH($size(k_i)), .RESET_VALUE(INITIAL_INTEGRAL)) i_ff_i (
		.clk(clk     ),
		.rst(reset   ),
		.d  (next_k_i),
		.q  (k_i     )
	);
	ff #(.D_WIDTH($size(k_d)), .RESET_VALUE(INITIAL_DERIVATIVE)) i_ff_d (
		.clk(clk     ),
		.rst(reset   ),
		.d  (next_k_d),
		.q  (k_d     )
	);
	ff #(.D_WIDTH(1)) i_ff_clken_32hz (
		.clk(clk             ),
		.rst(reset           ),
		.d  (clk_en_32hz     ),
		.q  (prev_clk_en_32hz)
	);
	// push buttons to increment or decrement PID parameters

	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn0 (
		.a_unsigned_in(sig_0     ),
		.b_signed_in  (50        ),
		.sum_out      (incr_sig_0)
	);

	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_0))) i_add_btn1 (
		.a_unsigned_in(sig_0     ),
		.b_signed_in  (-50       ),
		.sum_out      (decr_sig_0)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_1))) i_add_btn2 (
		.a_unsigned_in(sig_1     ),
		.b_signed_in  (50        ),
		.sum_out      (incr_sig_1)
	);
	saturating_adder_signed_unsigned #(.UNSIGNED_WIDTH($size(sig_1))) i_add_btn3 (
		.a_unsigned_in(sig_1     ),
		.b_signed_in  (-50       ),
		.sum_out      (decr_sig_1)
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
	// motor enable
	assign nand_bumper_btns       = ~(&bumper_btn); // convert to positive logic for connecting to debounce module
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			motor_en <= 0;
		else if(motor_en_sw)
			motor_en <= 0;
		else if(nand_bumper_btns_debounced)
			motor_en <= ~motor_en;
	end
	
	assign base_duty_cycle        = BASE_DUTY;
	assign duty_cycle_offset_adj  = (duty_cycle_offset > MAX_DUTY_CYCLE_OFFSET) ? MAX_DUTY_CYCLE_OFFSET : (duty_cycle_offset < -MAX_DUTY_CYCLE_OFFSET) ? -MAX_DUTY_CYCLE_OFFSET : duty_cycle_offset;
	assign distance_diag_setpoint = 30;
	

	assign fifo_ir_din = {
		{{(32-DIST_RESOLUTION){1'b0}},distance_diag},
		{{(32-DIST_RESOLUTION){1'b0}},distance_diag_setpoint},
		{{(32-ERROR_WIDTH){distance_error[ERROR_WIDTH-1]}},distance_error},
		{{(32-PROPORTIONAL_WIDTH){p_term[PROPORTIONAL_WIDTH-1]}},p_term},
		{{(32-INTEGRAL_WIDTH){i_term[INTEGRAL_WIDTH-1]}},i_term},
		{{(32-DERIVATIVE_WIDTH){d_term[DERIVATIVE_WIDTH-1]}},d_term},
		{{(32-DUTY_CYCLE_OFFSET_WIDTH){duty_cycle_offset_adj[PWM_RESOLUTION]}},duty_cycle_offset_adj}
	};
	assign fifo_ir_wr_en   = prev_clk_en_32hz & ~clk_en_32hz & ~fifo_ir_full & motor_en;
	assign fifo_uart_empty = fifo_ir_empty;
	assign fifo_uart_dout  = fifo_ir_dout;

	// PARAMETER CONTROL
	// straight wall
	// curved wall
	// sharp turns
	// wave object in front of sensor quickly
	assign sig_0                  = k_p;
	assign sig_1                  = k_d;
	assign modiy_sig0 = btn_debounce[0] ? incr_sig_0  : (btn_debounce[1] ? decr_sig_0 : sig_0);
	assign modify_sig1 = btn_debounce[2] ? incr_sig_1 : (btn_debounce[3] ? decr_sig_1 : sig_1);
	assign next_k_p = modiy_sig0;
	assign next_k_i = k_i;
	assign next_k_d = modify_sig1;


endmodule
