function drive_forward(robot, t, state, input)
    speed_sp(robot.motors.right, 60)
    speed_sp(robot.motors.left, 60)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
end

function turn_right(robot, t, state, input)
    speed_sp(robot.motors.right, -70)
    speed_sp(robot.motors.left, 30)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
end

function stop(robot, t, state, input)
    stop(robot.motors.right, "brake")
    stop(robot.motors.left, "brake")
    stop(robot.head, "coast")
end

function look_right(robot, t, state, input)
    position_sp(robot.head, 80 * 3)
    command(robot.head, "run-to-abs-pos")
end

function look_left(robot, t, state, input)
    position_sp(robot.head, -80 * 3)
    command(robot.head, "run-to-abs-pos")
end


function setup_mapping_behaviors(timeout=30)
    FORWARD = Behavior(drive_forward)
    TURN_RIGHT = Behavior(turn_right)
    STOP = Behavior(stop)
    DONE = Behavior(stop)
    LOOK_RIGHT = Behavior(look_right)
    LOOK_LEFT = Behavior(look_left)

    add_transition!(FORWARD, 
                    Transition((robot, t, state, input) -> input.ultrasound < 0.25, 
                               TURN_RIGHT))
    add_transition!(TURN_RIGHT, 
                    Transition((robot, t, state, input) -> input.ultrasound > 0.5,
                               FORWARD))
    add_transition!(LOOK_RIGHT,
                    Transition((robot, t, state, input) -> input.head_angle < -pi/4, 
                               LOOK_LEFT))
    add_transition!(LOOK_LEFT, 
                    Transition((robot, t, state, input) -> input.head_angle > pi/4, 
                               LOOK_RIGHT))

    for behavior in [FORWARD, TURN_RIGHT, LOOK_RIGHT, LOOK_LEFT]
        add_transition!(behavior, 
                        Transition((robot, t, state, input) -> t > timeout,
                                   STOP))
    end
    add_transition!(STOP,
                    Transition((robot, t, state, input) -> true, 
                               DONE))

    BehaviorSet([FORWARD, TURN_RIGHT, STOP, DONE, LOOK_RIGHT, LOOK_LEFT], [FORWARD, LOOK_RIGHT], DONE)
end