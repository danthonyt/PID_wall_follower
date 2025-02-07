module tachometer_interface (
    input logic clk_in, // 10 MHz clock
    input logic reset_in,
    input logic tachometer_pulse, // pulse from tachometer
    output logic [9:0] rpm_out // actual rpm of motor
);
always_ff @(posedge clk_in, posedge reset_in) begin
    
end
endmodule