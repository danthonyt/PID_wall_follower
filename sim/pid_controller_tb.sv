module pid_controller_tb ();
	// Parameters
	time CLK_PERIOD = 8ns;
// 125 MHz system clock
	logic clk ;
	logic reset;
	
	logic clk_en;
	logic en;
	logic [(17-9-3)-1:-8] k_p;	// 4:-8
	logic [(17-9-3)-1:-8] k_i;
	logic [(17-9-3)-1:-8] k_d;
	logic [8:0] setpoint;
	logic [8:0] feedback;
	logic signed [16:0] control_signal_out;
pid_controller #(.PID_FRAC_WIDTH(8), .PV_WIDTH(9), .CONTROL_WIDTH(17)) i_pid_controller (
	.clk               (clk               ),
	.reset             (reset             ),
	.clk_en            (clk_en            ),
	.en                (en),
	.k_p               (k_p               ),
	.k_i               (k_i               ),
	.k_d               (k_d               ),
	.setpoint          (setpoint          ),
	.feedback          (feedback          ),
	.control_signal_out(control_signal_out)
);
logic signed [15:-16] res;
logic signed [9:-8] a;
logic signed [5:-8] b;
logic signed [15:0]c;
assign c = res[15:0];
assign a = 'h3d800;
assign b = 'h0080;
assign res = a * b;
	assign clk_en = clk;
	initial begin
		clk = 0;
		forever begin
			#(CLK_PERIOD/2)  clk = ~ clk ;
		end
	end
	initial begin
		reset = 1;
		k_p = 13'h0080;
		k_d = 0;
		k_i = 0;
		en=1;
		setpoint = 100;
		feedback = 0;
		@(posedge clk);
		#(CLK_PERIOD); 
		reset = 0;
		#CLK_PERIOD;
		feedback = 40;
		#CLK_PERIOD;
		feedback = 140;
		#CLK_PERIOD;
		feedback = 20;
		#CLK_PERIOD;
		#CLK_PERIOD;

		$finish;
	end
endmodule