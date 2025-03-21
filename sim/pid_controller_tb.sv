module pid_controller_tb ();
	// Parameters
	// 125 MHz system clock
	time CLK_PERIOD = 8ns;
	// signal
	parameter PWM_RESOLUTION        = 17;
	parameter TACH_COUNT_RESOLUTION = 8 ;
	parameter ADC_RESOLUTION        = 16;
	parameter DIST_RESOLUTION       = 7 ;

	
	




	logic clk;
	logic reset;
	logic clk_en;
	logic en;
	logic unsigned [7:-8] k_p;
	logic unsigned [7:-8] k_i;
	logic unsigned [7:-8] k_d;
	logic unsigned [TACH_COUNT_RESOLUTION-1:0] setpoint;
	logic unsigned [TACH_COUNT_RESOLUTION-1:0] feedback;
	logic signed [TACH_COUNT_RESOLUTION:0] error;
	logic signed [PWM_RESOLUTION+1-1:0] control_out;
pid_controller #(
	.PID_INT_WIDTH (8),
	.PID_FRAC_WIDTH(8),
	.PV_WIDTH      (TACH_COUNT_RESOLUTION),
	.CONTROL_WIDTH (PWM_RESOLUTION+1)
) i_pid_controller (
	.clk        (clk        ),
	.reset      (reset      ),
	.clk_en     (clk_en     ),
	.en         (en         ),
	.k_p        (k_p        ),
	.k_i        (k_i        ),
	.k_d        (k_d        ),
	.setpoint   (setpoint   ),
	.feedback   (feedback   ),
	.error      (error      ),
	.control_out(control_out)
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
		k_p = 16'h0F00;
		k_i = 0;
		k_d = 0;
		setpoint = 0;
		feedback = 14;
		@(posedge clk);
		#(CLK_PERIOD);
		reset = 0;
		#CLK_PERIOD;
		repeat(100) begin
			setpoint = 5;//feedback = $urandom_range(300,0);
			#CLK_PERIOD;
		end
		#CLK_PERIOD

		$finish;
	end
endmodule