command(dev::Device, data::AbstractString) = in(data, dev.commands) ? dev.attr.command(data) : error("command $(data) not supported by device")

function values(sensor::Device{LegoSensor})
    vals = Vector{Float64}(sensor.attr.num_values())
    dec = sensor.attr.decimals()
    multiplier = 10.0 ^ (-dec)
    for j = 1:length(vals)
        vals[j] = multiplier * getfield(sensor.attr, symbol(:value, j-1))()
    end
    vals
end

function run(dev::Device{TachoMotor}, speed::Integer)
    dev.attr.speed_sp(speed)
    command(dev, "run-continuous")
end

function run(dev::Device{TachoMotor}, speed::Integer, timeout_ms::Integer)
    dev.attr.time_sp(timeout_ms)
    dev.attr.speed_sp(speed)
    command(dev, "run-timed")
end

function stop(dev::Device{TachoMotor}, stop_action::AbstractString)
    dev.attr.stop_action(stop_action)
    command(dev, "stop")
end

function run_to_position(dev::Device{TachoMotor}, degrees::Integer, absolute=true)
    ticks = int(round(absolute_degrees / 360. * dev.attr.count_per_rot()))
    dev.attr.position_sp(ticks)
    if absolute
        command(dev, "run-to-abs-pos")
    else
        command(dev, "run-to-rel-pos")
    end
end
