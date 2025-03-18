module motor_control_tb ();


	// Parameters
	time      CLK_PERIOD     = 8ns; // 125 Mhz clock
	parameter PWM_RESOLUTION = 16 ;
	parameter RPM_RESOLUTION = 10 ;
	//Ports
	logic                             clk                ;
	logic                             reset              ;
	logic                             clk_en             ;
	logic signed [  PWM_RESOLUTION:0] duty_cycle_offset_l;
	logic signed [  PWM_RESOLUTION:0] duty_cycle_offset_r;
	logic        [RPM_RESOLUTION-1:0] base_rpm           ;
	logic signed [  RPM_RESOLUTION:0] rpm_offset         ;
	logic        [PWM_RESOLUTION-1:0] duty_cycle_l       ;
	logic        [PWM_RESOLUTION-1:0] duty_cycle_r       ;
	logic        [RPM_RESOLUTION-1:0] rpm_setpoint_l     ;
	logic        [RPM_RESOLUTION-1:0] rpm_setpoint_r     ;
	motor_control #(.RPM_RESOLUTION(RPM_RESOLUTION), .PWM_RESOLUTION(PWM_RESOLUTION), .MAX_RPM_OFFSET(50)) i_motor_control (
		.clk                (clk                ),
		.clk_en             (clk_en             ),
		.reset              (reset              ),
		.duty_cycle_offset_l(duty_cycle_offset_l),
		.duty_cycle_offset_r(duty_cycle_offset_r),
		.base_rpm           (base_rpm           ),
		.rpm_offset         (rpm_offset         ),
		.duty_cycle_l       (duty_cycle_l       ),
		.duty_cycle_r       (duty_cycle_r       ),
		.rpm_setpoint_l     (rpm_setpoint_l     ),
		.rpm_setpoint_r     (rpm_setpoint_r     )
	);




	assign clk_en = clk;



	initial
		begin
			clk = 0;
			forever
				begin
					#(CLK_PERIOD/2)  clk = ~ clk ;
				end
		end
	initial
		begin
			reset = 1;
			duty_cycle_offset_r = 0;
			duty_cycle_offset_l = 0;
			base_rpm = 150;
			rpm_offset = 0;
			@(posedge clk);
			#(CLK_PERIOD/2);
			reset = 0;
			repeat(10) begin
				duty_cycle_offset_r = $random();
				duty_cycle_offset_l = $random();
				//base_rpm = $random();
				rpm_offset = $random();
				#(CLK_PERIOD*2);
			end
			repeat(10) begin
				duty_cycle_offset_r = $urandom_range(2**(PWM_RESOLUTION)-1,0);
				duty_cycle_offset_l = $urandom_range(2**(PWM_RESOLUTION)-1,0);
				//base_rpm = $urandom_range(2**(RPM_RESOLUTION)-1,0);
				rpm_offset = $urandom_range(2**(RPM_RESOLUTION)-1,0);
				#(CLK_PERIOD*2);
			end


			$finish;
		end


endmodule