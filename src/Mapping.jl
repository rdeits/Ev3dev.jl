# module Mapping

# using Ev3
using AffineTransforms

import Base: start, next, done, +

type Sides{T}
    right::T
    left::T
end 

start(sides::Sides) = :right
function next(sides::Sides, state)
    if state == :right
        next_state = :left
    else
        next_state = :done
    end
    getfield(sides, state), next_state
end
done(sides::Sides, state) = (state == :done)

type Odometer
    motor::Motor
    ticks_per_revolution
    meters_per_tick
    last_position
    total_distance
end

function Odometer(motor::Motor, meters_per_revolution::Real)
    ticks_per_revolution = count_per_rot(motor)
    meters_per_tick = meters_per_revolution / ticks_per_revolution
    current_position = position(motor)
    Odometer(motor, ticks_per_revolution, meters_per_tick, current_position, 0.0)
end


function unwrap_diff(x1, x2, modulus=2*pi)
    delta = x2 - x1
    delta = mod(delta, modulus)
    if delta > modulus / 2
        delta = delta - modulus
    end
    delta
end

function update!(odo::Odometer)
    current_position = position(odo.motor)
    delta = current_position - odo.last_position
    if abs(delta) > odo.ticks_per_revolution / 2
        # @show current_position
        # @show odo.last_position
        delta = mod(delta, odo.ticks_per_revolution)
        if delta > odo.ticks_per_revolution / 2
            delta = delta - odo.ticks_per_revolution
        end
        # @show delta
    end
    odo.last_position = current_position
    new_distance = delta * odo.meters_per_tick
    odo.total_distance += new_distance
    odo.total_distance
end

type State
    pose::AffineTransform
    last_wheel_distances::Sides
    last_orientation::Number
    head_direction::Number
end

type SensorData
    gyro::Number
    ultrasound::Number
    total_wheel_distances::Sides
    head_angle::Number

    SensorData() = new()
end

type MappingSensors
    gyro::Sensor
    ultrasound::Sensor
    odos::Sides{Odometer}
end

type RobotConfig
    hostname::AbstractString
    meters_per_revolution::Number
    gyro_port_name::AbstractString
    ultrasound_port_name::AbstractString
    motor_port_names::Sides
    head_port_name::AbstractString
    distance_between_wheels::Number
    T_origin_to_ultrasound::AffineTransform
end

type Robot
    config::RobotConfig
    motors::Sides{Motor}
    head::Motor
    sensors::MappingSensors
end

function Robot(config::RobotConfig)
    motors = Sides(Motor(config.motor_port_names.right, config.hostname), Motor(config.motor_port_names.left, config.hostname))
    head = Motor(config.head_port_name, config.hostname)
    odos = Sides(Odometer(motors.right, config.meters_per_revolution), Odometer(motors.left, config.meters_per_revolution))
    gyro = Sensor(config.gyro_port_name, config.hostname)
    ultrasound = Sensor(config.ultrasound_port_name, config.hostname)
    sensors = MappingSensors(gyro, ultrasound, odos)
    Robot(config, motors, head, sensors)
end


function update_input!(robot::Robot, t, state::State, input::SensorData)
    input.gyro = values(robot.sensors.gyro)[1] * pi / 180
    input.ultrasound = values(robot.sensors.ultrasound)[1] / 100
    input.total_wheel_distances = Sides(map(update!, robot.sensors.odos)...)
    input.head_angle = -position(robot.head) * 12 / 36 * pi / 180
end

function update_state!(robot::Robot, t, state::State, input::SensorData)
    angle_change = -(input.gyro - state.last_orientation)
    wheel_distances = [getfield(input.total_wheel_distances, field) - getfield(state.last_wheel_distances, field) for field in [:right, :left]]
    state.pose *= tformrigid([angle_change, mean(wheel_distances), 0])
    state.last_wheel_distances = input.total_wheel_distances
    state.last_orientation = input.gyro
    if state.head_direction > 0 && input.head_angle > pi/4
        state.head_direction = -1
    elseif state.head_direction < 0 && input.head_angle < -pi/4
        state.head_direction = 1
    end
end

immutable Transition
    test::Function
    destination
end

type Behavior
    action::Function
    transitions::Vector{Transition}

    Behavior(action::Function) = new(action, Transition[])
end

function add_transition!(behavior::Behavior, transition::Transition)
    push!(behavior.transitions, transition)
end

function drive_forward(robot, t, state, input)
    speed_sp(robot.motors.right, 60)
    speed_sp(robot.motors.left, 60)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
    position_sp(robot.head, -state.head_direction * 80 * 3)
    command(robot.head, "run-to-abs-pos")
end

function turn_right(robot, t, state, input)
    speed_sp(robot.motors.right, -70)
    speed_sp(robot.motors.left, 20)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
    position_sp(robot.head, -state.head_direction * 80 * 3)
    command(robot.head, "run-to-abs-pos")
end

function stop(robot, t, state, input)
    stop(robot.motors.right, "brake")
    stop(robot.motors.left, "brake")
    stop(robot.head, "coast")
end


type BehaviorSet
    behaviors::Vector{Behavior}
    starting::Behavior
    final::Behavior
end

function next(behavior::Behavior, robot, t, state, input)
    for transition in behavior.transitions
        if transition.test(robot, t, state, input)
            behavior = transition.destination
            break
        end
    end
    behavior
end

function setup_mapping_behaviors(timeout=30)
    FORWARD = Behavior(drive_forward)
    TURN_RIGHT = Behavior(turn_right)
    STOP = Behavior(stop)
    DONE = Behavior(stop)
    add_transition!(FORWARD, Transition((robot, t, state, input) -> input.ultrasound < 0.25, 
                                        TURN_RIGHT))
    add_transition!(TURN_RIGHT, Transition((robot, t, state, input) -> input.ultrasound > 0.5,
                                           FORWARD))
    for behavior in [FORWARD, TURN_RIGHT]
        add_transition!(behavior, Transition((robot, t, state, input) -> t > timeout,
                                              STOP))
    end
    add_transition!(STOP, Transition((robot, t, state, input) -> true, DONE))

    BehaviorSet([FORWARD, TURN_RIGHT, STOP, DONE], FORWARD, DONE)
end

type Map
    points::Vector{Tuple{Real, Real}}
    path::Vector{AffineTransform}
end

Map() = Map(Tuple{Real,Real}[], AffineTransform[])

+(m1::Map, m2::Map) = Map([m1.points; m2.points], [m1.path; m2.path])

function prep!(robot::Robot)
    speed_regulation(robot.motors.right, "on")
    speed_regulation(robot.motors.left, "on")
    speed_regulation(robot.head, "on")
    speed_sp(robot.head, 100)
end

function shutdown!(robot::Robot)
    map(stop, robot.motors)
    stop(robot.head)
end

function run_mapping(robot::Robot; timeout=30, initial_pose=tformeye(2))
    behaviors = setup_mapping_behaviors(timeout)

    current_behavior = behaviors.starting

    state = State(initial_pose,
                  Sides(0.0, 0.0),
                  0.0,
                  1)
    input = SensorData()
    start_time = time()
    local_map = Map()
    prep!(robot)

    try
        while current_behavior != behaviors.final
            t = time() - start_time
            update_input!(robot, t, state, input)
            update_state!(robot, t, state, input)
            if input.ultrasound < 2
                new_map_point = state.pose * robot.config.T_origin_to_ultrasound * tformrotate(input.head_angle) * tformtranslate([input.ultrasound, 0])
                push!(local_map.points, (new_map_point.offset...))
            end
            push!(local_map.path, state.pose)
            current_behavior = next(current_behavior, robot, t, state, input)
            current_behavior.action(robot, t, state, input)
        end
    finally
        shutdown!(robot)
    end

    local_map
end

function default_remote_robot(hostname)
    meters_per_revolution = 37.2 * 2.54 / 100 / 5 
    # 37.2 inches in 5 revolutions
    gyro_port = "in4"
    us_port = "in1"
    motor_ports = Sides("outD", "outB")
    head_port = "outA"
    distance_between_wheels = 4.5
    T_origin_to_ultrasound = tformtranslate(0.0254 * [2.0, 0.0])
    config = RobotConfig(hostname,
                         meters_per_revolution,
                         gyro_port,
                         us_port,
                         motor_ports,
                         head_port,
                         distance_between_wheels,
                         T_origin_to_ultrasound)

    robot = Robot(config)
    robot
end

# end