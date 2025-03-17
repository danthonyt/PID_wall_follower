module ascii_bin_to_hex (
	// converts binary values to ASCII hex values to send through UART
	input  logic [3:0] binary_in,
	output logic [7:0] hex_out
);
	always_comb begin
		unique case (binary_in)
			4'h0 : hex_out = 8'h30;
			4'h1 : hex_out = 8'h31;
			4'h2 : hex_out = 8'h32;
			4'h3 : hex_out = 8'h33;
			4'h4 : hex_out = 8'h34;
			4'h5 : hex_out = 8'h35;
			4'h6 : hex_out = 8'h36;
			4'h7 : hex_out = 8'h37;
			4'h8 : hex_out = 8'h38;
			4'h9 : hex_out = 8'h39;
			4'hA : hex_out = 8'h41;
			4'hB : hex_out = 8'h42;
			4'hC : hex_out = 8'h43;
			4'hD : hex_out = 8'h44;
			4'hE : hex_out = 8'h45;
			4'hF : hex_out = 8'h46;
		endcase
	end


endmodule