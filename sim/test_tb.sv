module test_tb ();
logic signed [2:-2] frac;
logic signed [2:-2] whole;
logic signed [5:-4] test;
logic signed [5:0] res;
assign frac = 'b11010;	// -1.5
assign whole ='b10100;	// -3
assign test = frac*whole;
assign res = test[5:0];	//10
endmodule