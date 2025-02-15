module navigation_fsm (
  input  logic        clk_in               ,
  input  logic        reset_in             ,
  // need to add ir sensor inputs
  input  logic        right_ir             ,
  input  logic        left_ir              ,
  input  logic        forward_ir           ,
  output logic [20:0] rpm_left_setpoint    , // desired rpm of left motor
  output logic [20:0] rpm_right_setpoint   , // desired rpm of right motor
  output logic        left_motor_en        ,
  output logic        right_motor_en       ,
  output logic        left_motor_direction ,
  output logic        right_motor_direction
);

  typedef enum logic [2:0] { FORWARD,TURN_LEFT,TURN_RIGHT,TURN_AROUND} states_t;
  states_t next_state, state;


  // Current State Logic -- sequential logic
  always_ff @(posedge clk_in or posedge reset_in)
    if (reset_in)
      state <= FORWARD;
    else
      state <= next_state;

  // Next State logic — combinational logic
  always_comb
    begin
      unique case (state)
        //prioritize right, then forward, then left, else turn around
        FORWARD :
          begin
            if (right_ir > threshold) next_state = TURN_RIGHT;
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
        left_motor_en = 1;
        right_motor_en = 1;
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
