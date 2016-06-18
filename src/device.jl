abstract Class{Name}

function call{T <: Class}(::Type{T}, brick::Brick, path::AbstractString)
    attr = T()
    for name in fieldnames(T)
        field_type = fieldtype(T, name)
        setfield!(attr, name, field_type(brick, path, name))
    end
    attr
end

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

name{C <: Class}(::Type{C}) = C.super.parameters[1]
class_path{C <: Class, D <: Driver}(::Type{Device{C, D}}) = joinpath("sys/class", replace(string(name(C)), '_', '-'))
name{N}(::Type{Driver{N}}) = N
driver_name{C, D <: Driver}(::Type{Device{C, D}}) = replace(string(name(D)), '_', '-')

function find_devices{T <: Device}(::Type{T}, brick::Brick)
    path = joinpath(brick.root_path, class_path(T))
    devices = Vector{T}()
    driver = driver_name(T)
    for dir in readdir(path)
        device_driver = open(joinpath(path, dir, "driver_name")) do f
            readchomp(f)
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

type TachoMotor <: Class{:tacho_motor}
    address::ReadOnly{ASCIIString}
    commands::ReadOnly{Vector{ASCIIString}}
    driver_name::ReadOnly{ASCIIString}
    command::WriteOnly{ASCIIString}
    count_per_rot::ReadOnly{Int}
    duty_cycle::ReadOnly{Int}
    duty_cycle_sp::ReadWrite{Int}
    speed_sp::ReadWrite{Int}
    position_sp::ReadWrite{Int}
    polarity::ReadWrite{ASCIIString}
    stop_action::ReadWrite{ASCIIString}
    stop_actions::ReadOnly{Vector{ASCIIString}}

    TachoMotor() = new()
end


type LegoSensor <: Class{:lego_sensor}
    address::ReadOnly{ASCIIString}
    commands::ReadOnly{Vector{ASCIIString}}
    driver_name::ReadOnly{ASCIIString}
    command::WriteOnly{ASCIIString}
    value0::ReadOnly{Int}
    value1::ReadOnly{Int}
    value2::ReadOnly{Int}
    value3::ReadOnly{Int}
    value4::ReadOnly{Int}
    value5::ReadOnly{Int}
    value6::ReadOnly{Int}
    value7::ReadOnly{Int}
    num_values::ReadOnly{Int}
    decimals::ReadOnly{Int}
    modes::ReadOnly{Vector{ASCIIString}}
    mode::ReadWrite{ASCIIString}
    bin_data::ReadOnly{ASCIIString}
    bin_data_format::ReadOnly{ASCIIString}
    poll_ms::ReadWrite{Int}

    LegoSensor() = new()
end
