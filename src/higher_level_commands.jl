command(dev::Device, data::AbstractString) = in(data, dev.commands) ? dev.attr.command(data) : error("command $(data) not supported by device")

function scaled_values(sensor::Device{LegoSensor})
    vals = Vector{Float64}(sensor.attr.num_values())
    dec = sensor.attr.decimals()
    multiplier = 10.0 ^ (-dec)
    for j = 1:length(vals)
        vals[j] = multiplier * getfield(sensor.attr, symbol(:value, j-1))()
    end
    vals
end

function run_continuous(dev::Device{TachoMotor}, speed::Integer)
    dev.attr.speed_sp(speed)
    command(dev, "run-forever")
end

function run_continuous(dev::Device{TachoMotor}, speed::Integer, timeout_ms::Integer)
    dev.attr.time_sp(timeout_ms)
    dev.attr.speed_sp(speed)
    command(dev, "run-timed")
end

function stop(dev::Device{TachoMotor}, stop_action::AbstractString="brake")
    dev.attr.stop_action(stop_action)
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

function servo_absolute(dev::Device{TachoMotor}, degrees::Degrees)
    ticks = int(round(absolute_degrees / 360. * dev.attr.count_per_rot()))
    dev.attr.position_sp(ticks)
    command(dev, "run-to-abs-pos")
end
servo_absolute(dev::Device{TachoMotor}, radians::Radians) = servo_absolute(dev, convert(Degrees, radians))

function servo_relative(dev::Device{TachoMotor}, degrees::Degrees)
    ticks = int(round(absolute_degrees / 360. * dev.attr.count_per_rot()))
    dev.attr.position_sp(ticks)
    command(dev, "run-to-rel-pos")
end
servo_relative(dev::Device{TachoMotor}, radians::Radians) = servo_relative(dev, convert(Degrees, radians))
