module Ev3

import Base: read, parse, write, call

immutable Brick
    root_path::AbstractString

    Brick(root_path::AbstractString="/") = new(root_path)
end

include("attributes.jl")
include("device.jl")
include("device_types.jl")
include("higher_level_commands.jl")

end
