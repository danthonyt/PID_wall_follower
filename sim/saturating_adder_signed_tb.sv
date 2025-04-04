module saturating_adder_signed_tb ();

	logic signed [7:0] a_in   ;
	logic signed [7:0] b_in   ;
	logic        [7:0] sum_out;
			saturating_adder_signed i_saturating_adder_signed (
				.a_in(a_in),
				.b_in(b_in),
				.sum_out(sum_out));
				      initial begin
				repeat(100)begin
				a_in = $random(
			);
			b_in = $random();
			#100;
		end
		a_in = 100;
		b_in = -10;
		#100;
		$finish;
	end
endmodule