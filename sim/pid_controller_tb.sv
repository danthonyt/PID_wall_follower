module pid_controller_tb ();
	// Parameters
	// 125 MHz system clock
	time CLK_PERIOD = 8ns;
	// signal
	parameter PID_INT_WIDTH    = 16   ;
	parameter DIST_RESOLUTION       = 7 ;
	parameter PWM_RESOLUTION = 17;
	localparam ERROR_WIDTH          =DIST_RESOLUTION+1;                     ;
	localparam PROPORTIONAL_WIDTH   = PID_INT_WIDTH + ERROR_WIDTH    ;
  localparam INTEGRAL_WIDTH       = PID_INT_WIDTH + ERROR_WIDTH    ;
  localparam DERIVATIVE_WIDTH     = PID_INT_WIDTH + ERROR_WIDTH + 1;
	logic clk;
	logic reset;
	logic clk_en;
	logic en;


	logic unsigned [PID_INT_WIDTH-1:0] k_p;
	logic unsigned [PID_INT_WIDTH-1:0] k_i;
	logic unsigned [PID_INT_WIDTH-1:0] k_d;
	logic unsigned [DIST_RESOLUTION-1:0] setpoint;
	logic unsigned [DIST_RESOLUTION-1:0] feedback;
	logic signed [DIST_RESOLUTION:0] error;
	logic signed [PWM_RESOLUTION+1-1:0] control_out;

	logic signed [PROPORTIONAL_WIDTH-1:0] u_p;
	logic signed [INTEGRAL_WIDTH-1:0] u_i;
	logic signed [DERIVATIVE_WIDTH-1:0] u_d;
pid_controller #(
	.PID_INT_WIDTH(PID_INT_WIDTH),
	.PV_WIDTH     (DIST_RESOLUTION),
	.CONTROL_WIDTH(PWM_RESOLUTION+1)
) i_pid_controller (
	.clk        (clk        ),
	.reset      (reset      ),
	.clk_en     (clk_en     ),
	.en         (en         ),
	.k_p        (k_p        ), // TODO: Check connection ! Signal/port not matching : Expecting logic [PID_INT_WIDTH-1:0]  -- Found logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] 
	.k_i        (k_i        ), // TODO: Check connection ! Signal/port not matching : Expecting logic [PID_INT_WIDTH-1:0]  -- Found logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] 
	.k_d        (k_d        ), // TODO: Check connection ! Signal/port not matching : Expecting logic [PID_INT_WIDTH-1:0]  -- Found logic [PID_INT_WIDTH-1:-PID_FRAC_WIDTH] 
	.setpoint   (setpoint   ),
	.feedback   (feedback   ),
	.control_out(control_out),
	.error      (error      ), // TODO: Check connection ! Signal/port not matching : Expecting logic [ERROR_WIDTH-1:0]  -- Found logic [DIST_RESOLUTION:0] 
	.u_p        (u_p        ),
	.u_i        (u_i        ),
	.u_d        (u_d        )
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
		k_p = 300;
		k_i = 100;
		k_d = 500;
		setpoint = 0;
		feedback = 14;
		@(posedge clk);
		#(CLK_PERIOD);
		reset = 0;
		#CLK_PERIOD;
		setpoint = 30;
		repeat(100) begin
			feedback = $urandom_range(56,7);
			if(control_out != u_p + u_i + u_d) $display("WRONG VALUE",);
			#CLK_PERIOD;
		end
		#CLK_PERIOD

		$finish;
	end
endmodule