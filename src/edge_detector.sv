module edge_detector (
    input logic clk_in,
    input logic sig_in,
    output logic pe_out
  );
  logic sig_q;
  always_ff @(posedge clk_in) begin
    sig_q <= sig_in;
  end
  assign pe_out = sig_in & ~sig_q;
  // with 125 Mhz clock the motor speed is 20,833,333 / Period
endmodule
