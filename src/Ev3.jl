module Ev3

import Base: read, parse, write, call

immutable Brick
    root_path::AbstractString

    Brick(root_path::AbstractString="/") = new(root_path)
end

include("attributes.jl")
include("device.jl")
include("device_types.jl")

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


end
