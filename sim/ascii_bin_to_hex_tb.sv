module ascii_bin_to_hex_tb ();
	// Parameters
	time CLK_PERIOD = 8ns;

	logic [3:0] binary_in;
	logic [7:0] hex_out  ;
	ascii_bin_to_hex i_ascii_bin_to_hex (
		.binary_in(binary_in),
		.hex_out  (hex_out  )
	);
	initial begin
		for (int i = 0; i < 16; i++) begin
			binary_in = i;
			#10;
			$display("output: %d",hex_out);
		end
		$finish;
	end
endmodule