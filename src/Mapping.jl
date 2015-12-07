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
    # if abs(delta) > odo.ticks_per_revolution / 2
    #     # @show current_position
    #     # @show odo.last_position
    #     delta = mod(delta, odo.ticks_per_revolution)
    #     if delta > odo.ticks_per_revolution / 2
    #         delta = delta - odo.ticks_per_revolution
    #     end
    #     # @show delta
    # end
    odo.last_position = current_position
    new_distance = delta * odo.meters_per_tick
    odo.total_distance += new_distance
    odo.total_distance
end

type State
    pose::AffineTransform
    last_wheel_distances::Sides
    last_orientation::Number
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
    input.gyro = -values(robot.sensors.gyro)[1] * pi / 180
    input.ultrasound = values(robot.sensors.ultrasound)[1] / 100
    input.total_wheel_distances = Sides(map(update!, robot.sensors.odos)...)
    input.head_angle = -position(robot.head) * 12 / 36 * pi / 180
end

function update_state!(robot::Robot, t, state::State, input::SensorData)
    angle_change = input.gyro - state.last_orientation
    wheel_distances = [getfield(input.total_wheel_distances, field) - getfield(state.last_wheel_distances, field) for field in [:right, :left]]
    state.pose *= tformrigid([angle_change, mean(wheel_distances), 0])
    state.last_wheel_distances = input.total_wheel_distances
    state.last_orientation = input.gyro
end

type Map
    points::Vector{Tuple{Real, Real}}
    path::Vector{AffineTransform}
end

Map() = Map(Tuple{Real,Real}[], AffineTransform[])

function prep!(robot::Robot)
    speed_regulation(robot.motors.right, "on")
    speed_regulation(robot.motors.left, "on")
    speed_regulation(robot.head, "on")
    speed_sp(robot.head, 130)
end

function shutdown!(robot::Robot)
    map(stop, robot.motors)
    stop(robot.head)
end

function run_mapping(robot::Robot; timeout=30, initial_pose=tformeye(2))
    behaviors = setup_mapping_behaviors(timeout)

    current_behaviors = behaviors.starting

    state = State(initial_pose,
                  Sides(0.0, 0.0),
                  -values(robot.sensors.gyro)[1] * pi / 180)
    input = SensorData()
    start_time = time()
    local_map = Map()
    prep!(robot)

    try
        while !all(current_behaviors .== behaviors.final)
            t = time() - start_time
            update_input!(robot, t, state, input)
            update_state!(robot, t, state, input)
            if input.ultrasound < 2
                new_map_point = state.pose * robot.config.T_origin_to_ultrasound * tformrotate(input.head_angle) * tformtranslate([input.ultrasound, 0])
                push!(local_map.points, (new_map_point.offset...))
            end
            push!(local_map.path, state.pose)
            current_behaviors = map(b -> next(b, robot, t, state, input), current_behaviors)
            map(b -> b.action(robot, t, state, input), current_behaviors)
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