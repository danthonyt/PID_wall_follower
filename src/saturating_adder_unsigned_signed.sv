module saturating_adder_signed_unsigned #(parameter UNSIGNED_WIDTH=8)(
    input logic [UNSIGNED_WIDTH-1:0] a_unsigned_in,
    input logic signed [UNSIGNED_WIDTH:0] b_signed_in,
    output logic [UNSIGNED_WIDTH-1:0] sum_out
);
    logic signed [UNSIGNED_WIDTH+1:0] temp_sum;
    localparam MAX_VALUE = (2**(UNSIGNED_WIDTH)-1);

    // Perform the addition with an extra bit for overflow detection
    assign temp_sum = $signed({1'd0,a_unsigned_in}) + b_signed_in;

    // Saturate if overflow or underflow occurs
    assign sum_out = (temp_sum > MAX_VALUE) ? MAX_VALUE :
                 (temp_sum < 0) ? 0 : temp_sum[UNSIGNED_WIDTH-1:0];

endmodule