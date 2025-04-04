module saturating_adder_signed #(parameter DATA_WIDTH=8) (
    input  logic signed [DATA_WIDTH-1:0] a_in   ,
    input  logic signed [DATA_WIDTH-1:0] b_in   ,
    output logic        [DATA_WIDTH-1:0] sum_out
);
    logic            signed [DATA_WIDTH:0] temp_sum                          ;
    localparam signed                      MAX_NEGATIVE = -(2**(DATA_WIDTH-1));
        localparam signed MAX_POSITIVE = (2**(DATA_WIDTH-1)-1);

        // Perform the addition with an extra bit for overflow detection
        assign temp_sum = a_in + b_in;

        // Saturate if overflow or underflow occurs
        always_comb begin
            if (temp_sum > MAX_POSITIVE)
                sum_out = MAX_POSITIVE;
            else if (temp_sum < MAX_NEGATIVE)
                sum_out = MAX_NEGATIVE;
            else
                sum_out = {temp_sum[DATA_WIDTH],temp_sum[DATA_WIDTH-2:0]};

        end

        endmodule