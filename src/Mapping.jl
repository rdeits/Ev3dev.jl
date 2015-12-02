# module Mapping

# using Ev3
using AffineTransforms

import Base: start, next, done

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
    meters_per_tick
    last_position
    total_distance
end

function Odometer(motor::Motor, meters_per_revolution::Real)
    ticks_per_revolution = count_per_rot(motor)
    meters_per_tick = meters_per_revolution / ticks_per_revolution
    current_position = position(motor)
    Odometer(motor, meters_per_tick, current_position, 0.0)
end

function update!(odo::Odometer)
    current_position = position(odo.motor)
    delta = current_position - odo.last_position
    if abs(delta) > 180
        error("wraparound not implemented")
    end
    odo.last_position = current_position
    new_distance = delta * odo.meters_per_tick
    odo.total_distance += new_distance
    odo.total_distance
end

type State
    pose::AffineTransform
    last_wheel_distances::Sides
    last_orientation::Real
end

type SensorData
    gyro::Real
    ultrasound::Real
    total_wheel_distances::Sides

    SensorData() = new()
end

type MappingSensors
    gyro::Sensor
    ultrasound::Sensor
    odos::Sides{Odometer}
end

type RobotConfig
    hostname::AbstractString
    meters_per_revolution::Real
    gyro_port_name::AbstractString
    ultrasound_port_name::AbstractString
    motor_port_names::Sides
    distance_between_wheels::Real
    T_origin_to_ultrasound::AffineTransform
end

type Robot
    config::RobotConfig
    motors::Sides{Motor}
    sensors::MappingSensors
end

function Robot(config::RobotConfig)
    motors = Sides(Motor(config.motor_port_names.right, config.hostname), Motor(config.motor_port_names.left, config.hostname))
    odos = Sides(Odometer(motors.right, config.meters_per_revolution), Odometer(motors.left, config.meters_per_revolution))
    gyro = Sensor(config.gyro_port_name, config.hostname)
    ultrasound = Sensor(config.ultrasound_port_name, config.hostname)
    sensors = MappingSensors(gyro, ultrasound, odos)
    Robot(config, motors, sensors)
end


function update_input!(robot::Robot, t, state::State, input::SensorData)
    input.gyro = values(robot.sensors.gyro)[1] * pi / 180
    input.ultrasound = values(robot.sensors.ultrasound)[1] / 100
    input.total_wheel_distances = Sides(map(update!, robot.sensors.odos)...)
end

function update_state!(robot::Robot, t, state::State, input::SensorData)
    angle_change = -(input.gyro - state.last_orientation)
    wheel_distances = [getfield(input.total_wheel_distances, field) - getfield(state.last_wheel_distances, field) for field in [:right, :left]]
    state.pose *= tformrigid([angle_change, mean(wheel_distances), 0])
    state.last_wheel_distances = input.total_wheel_distances
    state.last_orientation = input.gyro
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
    speed_sp(robot.motors.right, 100)
    speed_sp(robot.motors.left, 100)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
end

function turn_right(robot, t, state, input)
    speed_sp(robot.motors.right, -150)
    speed_sp(robot.motors.left, 50)
    command(robot.motors.right, "run-forever")
    command(robot.motors.left, "run-forever")
end

function stop(robot, t, state, input)
    stop(robot.motors.right, "brake")
    stop(robot.motors.left, "brake")
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

function setup_mapping_behaviors()
    FORWARD = Behavior(drive_forward)
    TURN_RIGHT = Behavior(turn_right)
    STOP = Behavior(stop)
    DONE = Behavior(stop)
    add_transition!(FORWARD, Transition((robot, t, state, input) -> input.ultrasound < 0.25, 
                                        TURN_RIGHT))
    add_transition!(TURN_RIGHT, Transition((robot, t, state, input) -> input.ultrasound > 0.5,
                                           FORWARD))
    for behavior in [FORWARD, TURN_RIGHT]
        add_transition!(behavior, Transition((robot, t, state, input) -> t > 30,
                                              STOP))
    end
    add_transition!(STOP, Transition((robot, t, state, input) -> true, DONE))

    BehaviorSet([FORWARD, TURN_RIGHT, STOP, DONE], FORWARD, DONE)
end

type Map
    points::Vector{Tuple{Real, Real}}
    path::Vector{AffineTransform}

    Map() = new([], [])
end

function run_mapping(robot::Robot)
    behaviors = setup_mapping_behaviors()

    current_behavior = behaviors.starting

    state = State(tformeye(2),
                  Sides(0.0, 0.0),
                  0.0)
    input = SensorData()
    start_time = time()
    map = Map()

    while current_behavior != behaviors.final
        t = time() - start_time
        update_input!(robot, t, state, input)
        update_state!(robot, t, state, input)
        if input.ultrasound < 2
            new_map_point = state.pose * robot.config.T_origin_to_ultrasound * tformtranslate([input.ultrasound, 0])
            push!(map.points, (new_map_point.offset...))
        end
        push!(map.path, state.pose)
        current_behavior = next(current_behavior, robot, t, state, input)
        current_behavior.action(robot, t, state, input)
    end

    map
end


# end