module navigation_fsm (
  input  logic        clk_in               ,
  input  logic        reset_in             ,
  // need to add ir sensor inputs
  input  logic [15:0] right_ir             ,
  input  logic [15:0] left_ir              ,
  input  logic        enable_switch        ,
  input  logic        forward_ir           ,
  output logic [25:0] rpm_left_setpoint    , // desired rpm of left motor
  output logic [25:0] rpm_right_setpoint   , // desired rpm of right motor
  output logic        left_motor_en        ,
  output logic        right_motor_en       ,
  output logic        left_motor_direction ,
  output logic        right_motor_direction
);

  typedef enum logic [2:0] { IDLE,FORWARD,TURN_LEFT,TURN_RIGHT,TURN_AROUND} states_t;
  states_t next_state, state;


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
        IDLE :
          begin
            if(enable_switch)
              next_state = FORWARD;
            else
              next_state = IDLE;
          end
        //prioritize right, then forward, then left, else turn around
        FORWARD :
          begin
            if (!enable_switch) next_state = IDLE;
            else if (right_ir > threshold) next_state = TURN_RIGHT;
            else if (forward_ir > threshold) next_state = FORWARD;
            else if (left_ir > threshold) next_state = TURN_LEFT;
            else next_state = TURN_AROUND;

          end
        TURN_LEFT   : next_state = FORWARD;
        TURN_RIGHT  : next_state = FORWARD;
        TURN_AROUND : next_state = FORWARD;
      endcase
    end

// FSM outputs — Moore architecture
  always_comb
    begin
      unique case (state)
        //prioritize right, then forward, then left, else turn around
        left_motor_en  = 1;
        right_motor_en = 1;
        IDLE:
        begin
          left_motor_en = 0;
          right_motor_en = 0;
        end
        FORWARD :
          begin
            left_motor_direction  = 1;
            right_motor_direction = 1;
            rpm_left_setpoint     = 100;
            rpm_right_setpoint    = 100;
          end
        TURN_LEFT :
          begin
            left_motor_direction  = 1;
            right_motor_direction = 1;
            rpm_left_setpoint     = 50;
            rpm_right_setpoint    = 100;
          end
        TURN_RIGHT :
          begin
            left_motor_direction  = 1;
            right_motor_direction = 1;
            rpm_left_setpoint     = 100;
            rpm_right_setpoint    = 50;
          end
        TURN_AROUND :
          begin
            left_motor_direction  = 1;
            right_motor_direction = 0;
            rpm_left_setpoint     = 100;
            rpm_right_setpoint    = 100;
          end
      endcase
    end
    always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
      adc_data <= {0,0,0,0,0,0,0,0,0,0};
      state    <= STATE_CONFIGURE;
      adc_idx <= 0;
    end else begin
      transaction_start <= 0;
      delay_en          <= 0;
      unique case (state)
        STATE_CONFIGURE : begin // modify adc config register 
          delay_en              <= 0;
          transaction_start     <= 1;
          rd_nwr                <= 0;
          din                   <= {8'h01, 8'h42,8'h43};
          transaction_bytes_num <= 3;
          state                 <= STATE_4MS_WAIT;
          next_state            <= STATE_SET;
        end
        STATE_SET : begin // switch to adc data register
          delay_en              <= 0;
          transaction_start     <= 1;
          rd_nwr                <= 0;
          din                   <= {8'h00,8'd0,8'd0};
          transaction_bytes_num <= 1;
          state                 <= STATE_4MS_WAIT;
          next_state            <= STATE_SAMPLE;

        end
        STATE_SAMPLE : begin  // read adc data register 
          delay_en              <= 0;
          transaction_start     <= 1;
          rd_nwr                <= 1;
          transaction_bytes_num <= 2;
          state                 <= STATE_4MS_WAIT;
          next_state            <= STATE_SAMPLE;
        end
        STATE_4MS_WAIT : begin  // wait for 10 ms 
          delay_en <= 1;

          if (transaction_done) begin 
            adc_data[adc_idx] <= {dout[0],dout[1]};
            adc_idx <= adc_idx + 1;
          end
          if(delay_counter == 500000) begin   // sample every 1 second
            state <= next_state;

          end
        end
      endcase
    end
  end
