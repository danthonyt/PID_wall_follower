module tachometer_interface (
    input logic clk_in, // 10 MHz clock
    input logic reset_in,
    input logic tachometer_pulse, // pulse from tachometer
    output logic [20:0] rpm_meas_out // actual rpm of motor
  );
  typedef enum logic [1:0] {IDLE,CNT_HIGH,CNT_LOW,UPDATE_RPM} states_t;
  states_t next_state, state;
  // RPM = 1 / (6*tachometer_period) for 360 pulses/revolution
  logic [15:0] period_count;

  // Current State Logic -- sequential logic
  always_ff @(posedge clk_in or posedge reset_in)
    if (reset_in)
      state <= IDLE;
    else
      state <= next_state;

  // Next State logic — combinational logic
  always_comb
  begin
    unique case (state)
             IDLE:
               if(tachometer_pulse)
                 next_state = CNT_HIGH;
               else
                 next_state = IDLE;
             CNT_HIGH:
               if(tachometer_pulse)
                 next_state = CNT_HIGH;
               else
                 next_state = CNT_LOW;
             CNT_LOW:
               if(tachometer_pulse)
                 next_state = UPDATE_RPM;
               else
                 next_state = CNT_LOW;
             UPDATE_RPM:
               next_state = CNT_HIGH;
           endcase
         end

         // FSM outputs — Moore architecture
         always_ff@(posedge clk_in or posedge reset_in)
         begin
           unique case (state)
                    IDLE:
                    begin
                      period_count <= 0;
                      rpm_meas_out <= 0;
                    end
                    CNT_HIGH,CNT_LOW:
                    begin
                      period_count <= period_count + 1;
                    end
                    UPDATE_RPM:
                    begin
                      period_count <= 1;
                      rpm_meas_out <= 1666667 / period_count;
                    end
                  endcase
                end
              endmodule
