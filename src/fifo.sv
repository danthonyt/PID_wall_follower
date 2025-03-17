module fifo #(
parameter DEPTH_POW_2=3, // holds DEPTH-1 elements. Depth = 2**(DEPTH_POW_2) 
parameter DWIDTH=16		 // Data width of each element
)(	
	input  logic              clk  , // Clock
	input  logic              rst  , // Active high reset
	input  logic              wr_en, // Write enable
	input  logic              rd_en, // Read enable
	input  logic [DWIDTH-1:0] din  , // Data written into FIFO
	output logic [DWIDTH-1:0] dout , // Data read from FIFO
	output logic              empty, // FIFO is empty when high
	output logic              full   // FIFO is full when high
);


	logic [$clog2(2**(DEPTH_POW_2))-1:0] wptr;
	logic [$clog2(2**(DEPTH_POW_2))-1:0] rptr;
	logic [$clog2(2**(DEPTH_POW_2))-1:0] incr_wptr;

	logic [DWIDTH-1:0] fifo[2**(DEPTH_POW_2)];

	always_ff@ (posedge clk) begin
		if (rst) begin
			wptr <= 0;
		end else begin
			if (wr_en && !full) begin
				fifo[wptr] <= din;
				wptr       <= wptr + 1;
			end
		end
	end
	always_ff@ (posedge clk) begin
		if (rst) begin
			rptr <= 0;
		end else begin
			if (rd_en && !empty) begin
				dout <= fifo[rptr];
				rptr <= rptr + 1;
			end
		end
	end
	assign incr_wptr = wptr + 1;
	assign full  = incr_wptr == rptr;
	assign empty = (wptr == rptr);
endmodule