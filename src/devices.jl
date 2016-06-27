abstract Driver{Name}

type Device{C <: Class, D <: Driver}
    attr::C
    commands::Set{ASCIIString}

    function Device(brick, path)
        attr = C(brick, path)
        commands = Set{ASCIIString}(attr.commands())
        new(attr, commands)
    end
end

class_path{C <: Class, D <: Driver}(::Type{Device{C, D}}) = class_path(C)
name{N}(::Type{Driver{N}}) = N
driver_name{C, D <: Driver}(::Type{Device{C, D}}) = replace(string(name(D)), '_', '-')

function find_devices{T <: Device}(::Type{T}, brick::Brick)
    path = joinpath(brick.root_path, class_path(T))
    devices = Vector{T}()
    driver = driver_name(T)
    for dir in readdir(path)
        device_driver = open(joinpath(path, dir, "driver_name")) do f
            chomp(strip(readline(f)))
        end
        if device_driver == driver
            push!(devices, T(brick, joinpath(path, dir)))
        end
    end
    devices
end

function find_device_at_address{T <: Device}(::Type{T}, brick::Brick, address::AbstractString)
    for dev in find_devices(T, brick)
        if dev.attr.address() == address
            return dev
        end
    end
    nothing
end

# Motors
typealias TachoMotor{Driver} Device{TachoMotorClass, Driver}

typealias LargeMotor TachoMotor{Driver{:lego_ev3_l_motor}}
typealias MediumMotor TachoMotor{Driver{:lego_ev3_m_motor}}

# Sensors
typealias LegoSensor{Driver} Device{LegoSensorClass, Driver}

typealias UltrasoundSensor LegoSensor{Driver{:lego_ev3_us}}
typealias ColorSensor LegoSensor{Driver{:lego_ev3_color}}
typealias TouchSensor LegoSensor{Driver{:lego_ev3_touch}}
typealias GyroSensor LegoSensor{Driver{:lego_ev3_gyro}}
