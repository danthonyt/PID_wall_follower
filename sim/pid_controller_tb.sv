module pid_controller_tb ();
	// Parameters
	// 125 MHz system clock
	time CLK_PERIOD = 8ns;
	// signal
	parameter PWM_RESOLUTION = 16;
	parameter RPM_RESOLUTION = 10;
	parameter ADC_RESOLUTION = 16;
	// wall follower PID parameters
	parameter PID_WALL_INT_WIDTH  = 8               ;
	parameter PID_WALL_FRAC_WIDTH = 8               ;
	parameter PV_WALL_WIDTH       = ADC_RESOLUTION  ;
	parameter CONTROL_WALL_WIDTH  = RPM_RESOLUTION+1;
	// tachometer PID parameters
	parameter PID_TACH_INT_WIDTH  = 8               ;
	parameter PID_TACH_FRAC_WIDTH = 8               ;
	parameter PV_TACH_WIDTH       = RPM_RESOLUTION  ;
	parameter CONTROL_TACH_WIDTH  = PWM_RESOLUTION+1;
	logic     clk                                   ;
	logic     reset                                 ;
	logic     clk_en                                ;
	logic     en                                    ;

	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_p_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_i_wall            ;
	logic unsigned [PID_WALL_INT_WIDTH-1:-PID_WALL_FRAC_WIDTH] k_d_wall            ;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_setpoint;
	logic unsigned [                        PV_WALL_WIDTH-1:0] distance_cm_measured;
	logic signed   [                          PV_WALL_WIDTH:0] distance_cm_error   ;
	logic signed   [                   CONTROL_WALL_WIDTH-1:0] rpm_offset          ;

	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_p_tach         ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_i_tach         ;
	logic unsigned [PID_TACH_INT_WIDTH-1:-PID_TACH_FRAC_WIDTH] k_d_tach         ;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_setpoint     ;
	logic unsigned [                        PV_TACH_WIDTH-1:0] rpm_measured     ;
	logic signed   [                          PV_TACH_WIDTH:0] rpm_error        ;
	logic signed   [                   CONTROL_TACH_WIDTH-1:0] duty_cycle_offset;

	
	pid_controller #(
		.PID_INT_WIDTH (PID_WALL_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_WALL_FRAC_WIDTH),
		.PV_WIDTH      (PV_WALL_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_WALL_WIDTH )
	) i_pid_controller_wall (
		.clk        (clk                 ),
		.reset      (reset               ),
		.clk_en     (clk_en              ),
		.en         (en                  ),
		.k_p        (k_p_wall            ),
		.k_i        (k_i_wall            ),
		.k_d        (k_d_wall            ),
		.setpoint   (distance_cm_setpoint),
		.feedback   (distance_cm_measured),
		.error      (distance_cm_error   ),
		.control_out(rpm_offset          )
	);

	
	pid_controller #(
		.PID_INT_WIDTH (PID_TACH_INT_WIDTH ),
		.PID_FRAC_WIDTH(PID_TACH_FRAC_WIDTH),
		.PV_WIDTH      (PV_TACH_WIDTH      ),
		.CONTROL_WIDTH (CONTROL_TACH_WIDTH )
	) i_pid_controller_tach (
		.clk        (clk              ),
		.reset      (reset            ),
		.clk_en     (clk_en           ),
		.en         (en               ),
		.k_p        (k_p_tach         ),
		.k_i        (k_i_tach         ),
		.k_d        (k_d_tach         ),
		.setpoint   (rpm_setpoint     ),
		.feedback   (rpm_measured     ),
		.error      (rpm_error        ),
		.control_out(duty_cycle_offset)
	);






	assign clk_en = clk;
	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		en=1;
		k_p_wall = 16'h00F0;
		k_i_wall = 0;
		k_d_wall = 0;
		k_p_tach = 16'h00F0;
		k_i_tach = 0;
		k_d_tach = 0;
		distance_cm_setpoint = 20;
		distance_cm_measured = 15;
		rpm_setpoint = 100;
		rpm_measured = 0;
		@(posedge clk);
		#(CLK_PERIOD);
		reset = 0;
		#CLK_PERIOD;
		repeat(100) begin
			distance_cm_measured = $urandom_range(80,15);
			rpm_measured = $urandom_range(300,0);
			#CLK_PERIOD;
		end
		#CLK_PERIOD

		$finish;
	end
endmodule