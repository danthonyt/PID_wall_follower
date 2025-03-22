module saturating_adder_unsigned_signed_tb ();


	// Parameters
	parameter UNSIGNED_WIDTH     = 8  ;

	//Ports
	logic        [UNSIGNED_WIDTH-1:0] a_unsigned_in;
	logic signed [  UNSIGNED_WIDTH:0] b_signed_in  ;
	logic        [UNSIGNED_WIDTH-1:0] sum_out      ;
	saturating_adder_signed_unsigned #(
		.UNSIGNED_WIDTH    (UNSIGNED_WIDTH    )
	) i_saturating_adder_signed_unsigned (
		.a_unsigned_in(a_unsigned_in),
		.b_signed_in  (b_signed_in  ),
		.sum_out      (sum_out      )
	);

// divisor of 18 is approx 100 hz with R = 16
	initial begin
		repeat(100)begin
			a_unsigned_in = $random();
			b_signed_in = $random();
			#100;
		end
		a_unsigned_in = 100;
		b_signed_in = -10;
		#100;
		$finish;
	end
endmodule