command(dev::Device, data::AbstractString) = in(data, dev.commands) ? dev.io.command(data) : error("command $(data) not supported by device")

function scaled_values(sensor::LegoSensor)
    vals = Vector{Float64}(sensor.io.num_values())
    dec = sensor.io.decimals()
    multiplier = 10.0 ^ (-dec)
    for j = 1:length(vals)
        vals[j] = multiplier * getfield(sensor.io, symbol(:value, j-1))()
    end
    vals
end

function run_continuous(dev::TachoMotor, speed::Integer)
    dev.io.speed_regulation("on")
    dev.io.speed_sp(speed)
    command(dev, "run-forever")
end

function run_continuous(dev::TachoMotor, speed::Integer, timeout_ms::Integer)
    dev.io.time_sp(timeout_ms)
    dev.io.speed_regulation("on")
    dev.io.speed_sp(speed)
    command(dev, "run-timed")
end

function stop(dev::TachoMotor, stop_command::AbstractString="brake")
    dev.io.stop_command(stop_command)
    command(dev, "stop")
end

abstract Angular{T}

immutable Degrees{T} <: Angular{T}
    value::T
end

immutable Radians{T} <: Angular{T}
    value::T
end

convert(::Type{Degrees}, rad::Radians) = radians.value * 180 / pi
convert(::Type{Radians}, deg::Degrees) = degrees.value * pi / 180

function servo_absolute(dev::TachoMotor, degrees::Degrees, speed=nothing)
    ticks = round(Int, degrees.value / 360. * dev.io.count_per_rot())
    dev.io.speed_regulation("on")
    (speed !== nothing) && dev.io.speed_sp(speed)
    dev.io.position_sp(ticks)
    command(dev, "run-to-abs-pos")
end
servo_absolute(dev::TachoMotor, radians::Radians) = servo_absolute(dev, convert(Degrees, radians))

function servo_relative(dev::TachoMotor, degrees::Degrees, speed=nothing)
    ticks = round(Int, degrees.value / 360. * dev.io.count_per_rot())
    dev.io.speed_regulation("on")
    (speed !== nothing) && dev.io.speed_sp(speed)
    dev.io.position_sp(ticks)
    command(dev, "run-to-rel-pos")
end
servo_relative(dev::TachoMotor, radians::Radians) = servo_relative(dev, convert(Degrees, radians))
