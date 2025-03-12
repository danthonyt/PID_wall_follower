`timescale 1ns/1ps
module uart_top #(
    // 5 to 9 data bits
    parameter DATA_WIDTH=8,
    // baud rate
    parameter CLKS_PER_BIT=87
  )(
    //input logic clk,
    input logic reset,
    input logic start,
    input logic serial_rx,
    input logic [(DATA_WIDTH-1):0] din_tx,
    output logic [(DATA_WIDTH-1):0] dout_rx,
    output logic serial_tx,
    output logic done
  );
  uart_tx #(
            .DATA_WIDTH(DATA_WIDTH),
            .CLKS_PER_BIT(CLKS_PER_BIT)
          )
          tx (
            .clk (clk),
            .reset (reset),
            .start (start),
            .din (din_tx),
            .serial_tx(serial_tx),
            .done (done)
          );
  uart_rx #(
            .DATA_WIDTH(DATA_WIDTH),
            .CLKS_PER_BIT(CLKS_PER_BIT)
          )
          rx (
            .clk (clk),
            .reset (reset),
            .serial_rx(serial_rx),
            .dout (dout_rx)
          );
endmodule
